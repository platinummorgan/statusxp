-- ============================================================================
-- CRITICAL FINDINGS FROM DATABASE ASSESSMENT
-- ============================================================================

-- V2 TABLES HAVE PRODUCTION DATA - CANNOT JUST DROP THEM
-- =======================================================
-- games_v2:              5,109 rows
-- achievements_v2:     142,569 rows (similar to original 143,090)
-- user_achievements_v2: 57,777 rows ⚠️ THIS IS 70% OF THE TOTAL DATA
-- user_progress_v2:      3,069 rows
--
-- Original tables:
-- game_titles:          4,355 rows
-- achievements:       143,090 rows
-- user_achievements:   82,830 rows
-- user_games:           7,340 rows
--
-- CONCLUSION: Data is SPLIT between V2 and original tables!
-- We have ~57K achievements in V2 and ~82K in original (with likely overlap)

-- STATUSXP IS SEVERELY BROKEN
-- ============================
-- user_achievements: 48,135 out of 82,830 (58%) have NO StatusXP
-- user_games:         2,162 out of  7,340 (30%) have NO StatusXP
--
-- StatusXP functions still exist but are NOT being triggered:
-- - calculate_user_achievement_statusxp
-- - calculate_user_game_statusxp
-- - recalculate_achievement_rarity

-- RECOVERY STRATEGY
-- =================
-- PHASE 1: Merge V2 data back into original tables (preserve all data)
-- PHASE 2: Drop V2 tables once data is consolidated
-- PHASE 3: Recalculate StatusXP for ALL achievements and games
-- PHASE 4: Restore StatusXP triggers so future data auto-calculates
-- PHASE 5: Verify data integrity and rebuild leaderboards

-- ============================================================================
-- PHASE 1: MERGE V2 DATA INTO ORIGINAL TABLES
-- ============================================================================
-- This script carefully merges V2 data back into original tables
-- without creating duplicates

-- Step 1: Find achievements that exist in V2 but NOT in original
-- (These need to be inserted)
SELECT 
  'Achievements only in V2' as check_type,
  COUNT(*) as count
FROM achievements_v2 av2
WHERE NOT EXISTS (
  SELECT 1 FROM achievements a
  WHERE a.platform_achievement_id = av2.platform_achievement_id
    AND a.platform = (
      CASE 
        WHEN av2.platform_id = 1 THEN 'psn'
        WHEN av2.platform_id IN (2,3,4) THEN 'xbox'
        WHEN av2.platform_id = 5 THEN 'steam'
      END
    )
);

-- Step 2: Find user achievements that exist in V2 but NOT in original
SELECT 
  'User achievements only in V2' as check_type,
  COUNT(*) as count
FROM user_achievements_v2 uav2
WHERE NOT EXISTS (
  SELECT 1 FROM user_achievements ua
  JOIN achievements a ON a.id = ua.achievement_id
  WHERE ua.user_id = uav2.user_id
    AND a.platform_achievement_id = uav2.platform_achievement_id
);

-- Step 3: Find duplicate user achievements (in BOTH V2 and original)
-- These might have different earned_at times - we keep the EARLIEST
SELECT 
  'Duplicate user achievements' as check_type,
  COUNT(*) as count
FROM user_achievements_v2 uav2
WHERE EXISTS (
  SELECT 1 FROM user_achievements ua
  JOIN achievements a ON a.id = ua.achievement_id
  WHERE ua.user_id = uav2.user_id
    AND a.platform_achievement_id = uav2.platform_achievement_id
);

-- Step 4: Compare user_games vs user_progress_v2
-- See which games are only tracked in V2
SELECT 
  'Games tracked only in V2' as check_type,
  COUNT(*) as count
FROM user_progress_v2 upv2
WHERE NOT EXISTS (
  SELECT 1 FROM user_games ug
  JOIN game_titles gt ON gt.id = ug.game_title_id
  WHERE ug.user_id = upv2.user_id
    AND ug.platform_id = upv2.platform_id
    AND (
      (upv2.platform_id = 1 AND gt.psn_npwr_id = upv2.platform_game_id)
      OR (upv2.platform_id IN (2,3,4) AND gt.xbox_title_id = upv2.platform_game_id)
      OR (upv2.platform_id = 5 AND gt.steam_app_id = upv2.platform_game_id)
    )
);

-- ============================================================================
-- PHASE 2: ACTUAL MERGE OPERATIONS
-- ============================================================================
-- ⚠️ DO NOT RUN THIS YET - This is the preview of what we'll do
-- ============================================================================

-- TODO: Build merge queries that:
-- 1. Insert achievements from V2 that don't exist in original
-- 2. Insert user_achievements from V2 that don't exist in original
-- 3. Update earned_at dates if V2 has earlier timestamps
-- 4. Consolidate user_games with user_progress_v2 data
-- 5. Verify counts match before dropping V2 tables
