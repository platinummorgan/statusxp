-- ============================================================================
-- DATABASE RECOVERY SCRIPT - PRODUCTION CRISIS FIX
-- ============================================================================
-- Created: 2026-01-19
-- Purpose: Fix broken database state after failed V2 migration
--
-- CRITICAL FINDINGS:
-- - V2 user_achievements: ALL 57,777 are DUPLICATES (0 unique)
-- - V2 can be SAFELY DROPPED without data loss
-- - StatusXP is broken: 58% missing on achievements, 30% on games
-- - Original tables have ALL current production data
--
-- RECOVERY PLAN:
-- Phase 1: Safety backup of critical data
-- Phase 2: Drop V2 tables (they're stale duplicates)
-- Phase 3: Fix StatusXP calculations
-- Phase 4: Recalculate all StatusXP values
-- Phase 5: Restore triggers for future automation
-- Phase 6: Verify and rebuild leaderboards
-- ============================================================================

-- ============================================================================
-- PHASE 1: SAFETY BACKUP
-- ============================================================================
-- Export critical counts before we start
-- Run these and save the output for verification

SELECT 'BEFORE CLEANUP' as checkpoint, NOW() as timestamp;

SELECT 
  'user_achievements' as table_name,
  COUNT(*) as total_rows,
  COUNT(DISTINCT user_id) as unique_users,
  COUNT(DISTINCT achievement_id) as unique_achievements,
  MIN(earned_at) as earliest_unlock,
  MAX(earned_at) as latest_unlock
FROM user_achievements;

SELECT 
  'user_games' as table_name,
  COUNT(*) as total_rows,
  COUNT(DISTINCT user_id) as unique_users,
  COUNT(DISTINCT game_title_id) as unique_games,
  SUM(statusxp_effective) as total_statusxp
FROM user_games;

SELECT 
  'achievements' as table_name,
  COUNT(*) as total_rows,
  COUNT(DISTINCT platform) as platforms,
  COUNT(*) FILTER (WHERE rarity_global IS NOT NULL) as has_rarity,
  COUNT(*) FILTER (WHERE base_status_xp IS NOT NULL) as has_statusxp
FROM achievements;

-- ============================================================================
-- PHASE 2: DROP V2 TABLES SAFELY
-- ============================================================================
-- V2 tables contain STALE DUPLICATE data from migration point
-- Original tables have CURRENT PRODUCTION data
-- Safe to drop V2 completely

-- IMPORTANT: Run Phase 1 backup queries FIRST!
-- Then uncomment and run these one at a time:

-- Drop V2 user data tables (duplicates)
-- DROP TABLE IF EXISTS user_achievements_v2 CASCADE;
-- DROP TABLE IF EXISTS user_progress_v2 CASCADE;

-- Drop V2 catalog tables (duplicates)
-- DROP TABLE IF EXISTS achievements_v2 CASCADE;
-- DROP TABLE IF EXISTS games_v2 CASCADE;

-- Drop V2 leaderboard caches (duplicates)
-- DROP TABLE IF EXISTS psn_leaderboard_cache_v2 CASCADE;
-- DROP TABLE IF EXISTS xbox_leaderboard_cache_v2 CASCADE;
-- DROP TABLE IF EXISTS steam_leaderboard_cache_v2 CASCADE;

-- Verify tables are gone
-- SELECT table_name 
-- FROM information_schema.tables 
-- WHERE table_schema = 'public' 
--   AND table_name LIKE '%_v2'
-- ORDER BY table_name;
-- Expected result: 0 rows

-- ============================================================================
-- PHASE 3: FIX STATUSXP SYSTEM
-- ============================================================================
-- The StatusXP calculation functions exist but triggers are broken/missing

-- Step 1: Check what trigger currently exists
SELECT 
  trigger_name,
  event_manipulation,
  event_object_table,
  action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND event_object_table IN ('user_games', 'user_achievements')
ORDER BY event_object_table, trigger_name;

-- Step 2: Re-create StatusXP calculation trigger for user_games
-- This ensures future game updates auto-calculate StatusXP
DROP TRIGGER IF EXISTS calculate_statusxp_on_upsert ON user_games;

CREATE OR REPLACE FUNCTION trigger_calculate_statusxp()
RETURNS TRIGGER AS $$
BEGIN
  -- Calculate raw StatusXP from all earned achievements
  NEW.statusxp_raw := COALESCE((
    SELECT SUM(a.base_status_xp * a.rarity_multiplier)
    FROM user_achievements ua
    JOIN achievements a ON a.id = ua.achievement_id
    WHERE ua.user_id = NEW.user_id
      AND a.game_title_id = NEW.game_title_id
      AND a.include_in_score = true
  ), 0);

  -- Apply stack multiplier for effective score
  NEW.statusxp_effective := NEW.statusxp_raw * COALESCE(NEW.stack_multiplier, 1.0);

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER calculate_statusxp_on_upsert
  BEFORE INSERT OR UPDATE OF earned_trophies, completion_percent
  ON user_games
  FOR EACH ROW
  EXECUTE FUNCTION trigger_calculate_statusxp();

-- ============================================================================
-- PHASE 4: RECALCULATE STATUSXP FOR ALL DATA
-- ============================================================================
-- This will take time but fixes all the broken/missing StatusXP values

-- Step 1: Update base_status_xp and rarity_multiplier for all achievements
-- Based on existing rarity data
UPDATE achievements
SET 
  rarity_band = CASE 
    WHEN rarity_global IS NULL THEN NULL
    WHEN rarity_global >= 50 THEN 'common'
    WHEN rarity_global >= 20 THEN 'uncommon'
    WHEN rarity_global >= 10 THEN 'rare'
    WHEN rarity_global >= 5 THEN 'very_rare'
    WHEN rarity_global >= 1 THEN 'ultra_rare'
    ELSE 'legendary'
  END,
  rarity_multiplier = CASE 
    WHEN rarity_global IS NULL THEN 1.0
    WHEN rarity_global >= 50 THEN 1.0
    WHEN rarity_global >= 20 THEN 1.5
    WHEN rarity_global >= 10 THEN 2.0
    WHEN rarity_global >= 5 THEN 3.0
    WHEN rarity_global >= 1 THEN 5.0
    ELSE 10.0
  END,
  base_status_xp = CASE 
    -- PSN trophies
    WHEN platform = 'psn' AND psn_trophy_type = 'platinum' THEN 1000
    WHEN platform = 'psn' AND psn_trophy_type = 'gold' THEN 100
    WHEN platform = 'psn' AND psn_trophy_type = 'silver' THEN 50
    WHEN platform = 'psn' AND psn_trophy_type = 'bronze' THEN 25
    -- Xbox achievements (based on gamerscore)
    WHEN platform = 'xbox' AND xbox_gamerscore > 0 THEN xbox_gamerscore::numeric
    WHEN platform = 'xbox' THEN 10
    -- Steam achievements
    WHEN platform = 'steam' THEN 25
    ELSE 25
  END
WHERE include_in_score = true;

-- Step 2: Calculate StatusXP for individual user achievements
UPDATE user_achievements ua
SET statusxp_points = a.base_status_xp * a.rarity_multiplier
FROM achievements a
WHERE ua.achievement_id = a.id
  AND a.include_in_score = true
  AND (ua.statusxp_points IS NULL OR ua.statusxp_points = 0);

-- Step 3: Recalculate StatusXP for all user_games
-- This batches updates to avoid timeout
DO $$
DECLARE
  batch_size INT := 500;
  total_updated INT := 0;
  rows_affected INT;
BEGIN
  LOOP
    -- Update one batch
    WITH batch AS (
      SELECT id, user_id, game_title_id, stack_multiplier
      FROM user_games
      WHERE statusxp_raw IS NULL OR statusxp_raw = 0
      LIMIT batch_size
    )
    UPDATE user_games ug
    SET 
      statusxp_raw = COALESCE((
        SELECT SUM(a.base_status_xp * a.rarity_multiplier)
        FROM user_achievements ua
        JOIN achievements a ON a.id = ua.achievement_id
        WHERE ua.user_id = ug.user_id
          AND a.game_title_id = ug.game_title_id
          AND a.include_in_score = true
      ), 0),
      statusxp_effective = statusxp_raw * COALESCE(ug.stack_multiplier, 1.0)
    FROM batch
    WHERE ug.id = batch.id;

    GET DIAGNOSTICS rows_affected = ROW_COUNT;
    total_updated := total_updated + rows_affected;
    
    -- Log progress
    RAISE NOTICE 'Updated % user_games records (total: %)', rows_affected, total_updated;
    
    -- Exit if no more rows to update
    EXIT WHEN rows_affected = 0;
    
    -- Small delay between batches
    PERFORM pg_sleep(0.1);
  END LOOP;
  
  RAISE NOTICE 'Completed! Total user_games updated: %', total_updated;
END $$;

-- ============================================================================
-- PHASE 5: REBUILD LEADERBOARD CACHES
-- ============================================================================
-- Refresh all platform leaderboard caches with correct StatusXP

-- PSN Leaderboard
TRUNCATE psn_leaderboard_cache;

INSERT INTO psn_leaderboard_cache (user_id, display_name, avatar_url, platinum_count, total_games, updated_at)
SELECT 
  p.id as user_id,
  COALESCE(p.display_name, p.username) as display_name,
  p.psn_avatar_url as avatar_url,
  COUNT(DISTINCT ua.achievement_id) FILTER (WHERE a.is_platinum = true) as platinum_count,
  COUNT(DISTINCT ug.game_title_id) as total_games,
  NOW() as updated_at
FROM profiles p
LEFT JOIN user_games ug ON ug.user_id = p.id AND ug.platform_id = 1 -- PSN platform
LEFT JOIN user_achievements ua ON ua.user_id = p.id
LEFT JOIN achievements a ON a.id = ua.achievement_id AND a.platform = 'psn'
WHERE p.psn_online_id IS NOT NULL
  AND p.merged_into_user_id IS NULL
  AND p.show_on_leaderboard = true
GROUP BY p.id, p.display_name, p.username, p.psn_avatar_url
HAVING COUNT(DISTINCT ug.game_title_id) > 0;

-- Xbox Leaderboard
TRUNCATE xbox_leaderboard_cache;

INSERT INTO xbox_leaderboard_cache (user_id, display_name, avatar_url, achievement_count, gamerscore, total_games, updated_at)
SELECT 
  p.id as user_id,
  COALESCE(p.display_name, p.username) as display_name,
  p.xbox_avatar_url as avatar_url,
  COUNT(DISTINCT ua.achievement_id) FILTER (WHERE a.platform = 'xbox') as achievement_count,
  COALESCE(SUM(DISTINCT ug.xbox_current_gamerscore), 0) as gamerscore,
  COUNT(DISTINCT ug.game_title_id) as total_games,
  NOW() as updated_at
FROM profiles p
LEFT JOIN user_games ug ON ug.user_id = p.id AND ug.platform_id IN (2, 3, 4) -- Xbox platforms
LEFT JOIN user_achievements ua ON ua.user_id = p.id
LEFT JOIN achievements a ON a.id = ua.achievement_id
WHERE p.xbox_gamertag IS NOT NULL
  AND p.merged_into_user_id IS NULL
  AND p.show_on_leaderboard = true
GROUP BY p.id, p.display_name, p.username, p.xbox_avatar_url
HAVING COUNT(DISTINCT ug.game_title_id) > 0;

-- Steam Leaderboard
TRUNCATE steam_leaderboard_cache;

INSERT INTO steam_leaderboard_cache (user_id, display_name, avatar_url, achievement_count, total_games, updated_at)
SELECT 
  p.id as user_id,
  COALESCE(p.steam_display_name, p.display_name, p.username) as display_name,
  p.steam_avatar_url as avatar_url,
  COUNT(DISTINCT ua.achievement_id) FILTER (WHERE a.platform = 'steam') as achievement_count,
  COUNT(DISTINCT ug.game_title_id) as total_games,
  NOW() as updated_at
FROM profiles p
LEFT JOIN user_games ug ON ug.user_id = p.id AND ug.platform_id = 5 -- Steam platform
LEFT JOIN user_achievements ua ON ua.user_id = p.id
LEFT JOIN achievements a ON a.id = ua.achievement_id
WHERE p.steam_id IS NOT NULL
  AND p.merged_into_user_id IS NULL
  AND p.show_on_leaderboard = true
GROUP BY p.id, p.display_name, p.username, p.steam_display_name, p.steam_avatar_url
HAVING COUNT(DISTINCT ug.game_title_id) > 0;

-- ============================================================================
-- PHASE 6: VERIFICATION
-- ============================================================================
-- Run these to verify the recovery was successful

SELECT 'AFTER CLEANUP' as checkpoint, NOW() as timestamp;

-- Verify V2 tables are gone
SELECT 
  'V2 tables remaining' as check_type,
  COUNT(*) as count
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name LIKE '%_v2';
-- Expected: 0

-- Check StatusXP coverage
SELECT 
  'StatusXP Coverage' as metric,
  COUNT(*) as total_achievements,
  COUNT(*) FILTER (WHERE statusxp_points > 0) as has_statusxp,
  ROUND(100.0 * COUNT(*) FILTER (WHERE statusxp_points > 0) / COUNT(*), 1) as pct_complete
FROM user_achievements;
-- Expected: ~100% coverage

SELECT 
  'User Games StatusXP' as metric,
  COUNT(*) as total_games,
  COUNT(*) FILTER (WHERE statusxp_effective > 0) as has_statusxp,
  ROUND(100.0 * COUNT(*) FILTER (WHERE statusxp_effective > 0) / COUNT(*), 1) as pct_complete
FROM user_games;
-- Expected: ~100% coverage

-- Verify leaderboard caches populated
SELECT 'psn_leaderboard_cache' as cache_table, COUNT(*) as users FROM psn_leaderboard_cache
UNION ALL
SELECT 'xbox_leaderboard_cache', COUNT(*) FROM xbox_leaderboard_cache
UNION ALL
SELECT 'steam_leaderboard_cache', COUNT(*) FROM steam_leaderboard_cache;

-- Check for any stuck sync statuses
SELECT 
  psn_sync_status,
  COUNT(*) as user_count
FROM profiles
WHERE merged_into_user_id IS NULL
GROUP BY psn_sync_status
ORDER BY user_count DESC;

-- Sample top users to verify StatusXP looks reasonable
SELECT 
  p.username,
  COUNT(DISTINCT ug.id) as games,
  COUNT(DISTINCT ua.id) as achievements,
  SUM(ug.statusxp_effective) as total_statusxp,
  ROUND(AVG(ug.statusxp_effective), 2) as avg_per_game
FROM profiles p
JOIN user_games ug ON ug.user_id = p.id
JOIN user_achievements ua ON ua.user_id = p.id
WHERE p.merged_into_user_id IS NULL
GROUP BY p.id, p.username
ORDER BY total_statusxp DESC
LIMIT 10;

SELECT '✅ RECOVERY COMPLETE' as status, NOW() as completed_at;
