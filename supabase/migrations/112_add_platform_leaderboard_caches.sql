-- Migration: 112_add_platform_leaderboard_caches.sql
-- Created: 2025-12-30
-- Description: Create cached leaderboard tables for PSN/Xbox/Steam (like StatusXP has)
-- This makes all leaderboard tabs instant by pre-computing rankings

-- ============================================================================
-- PSN PLATINUM LEADERBOARD CACHE
-- ============================================================================
CREATE TABLE IF NOT EXISTS psn_leaderboard_cache (
  user_id UUID PRIMARY KEY,
  display_name TEXT,
  avatar_url TEXT,
  platinum_count BIGINT DEFAULT 0,
  total_games BIGINT DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_psn_leaderboard_cache_platinum 
  ON psn_leaderboard_cache(platinum_count DESC, total_games DESC);

-- ============================================================================
-- XBOX LEADERBOARD CACHE
-- ============================================================================
CREATE TABLE IF NOT EXISTS xbox_leaderboard_cache (
  user_id UUID PRIMARY KEY,
  display_name TEXT,
  avatar_url TEXT,
  achievement_count BIGINT DEFAULT 0,
  total_games BIGINT DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_xbox_leaderboard_cache_achievements 
  ON xbox_leaderboard_cache(achievement_count DESC, total_games DESC);

-- ============================================================================
-- STEAM LEADERBOARD CACHE
-- ============================================================================
CREATE TABLE IF NOT EXISTS steam_leaderboard_cache (
  user_id UUID PRIMARY KEY,
  display_name TEXT,
  avatar_url TEXT,
  achievement_count BIGINT DEFAULT 0,
  total_games BIGINT DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_steam_leaderboard_cache_achievements 
  ON steam_leaderboard_cache(achievement_count DESC, total_games DESC);

-- ============================================================================
-- REFRESH FUNCTIONS (called by trigger when achievements sync)
-- ============================================================================

-- Refresh PSN Leaderboard Cache
CREATE OR REPLACE FUNCTION refresh_psn_leaderboard_cache()
RETURNS void AS $$
BEGIN
  -- Clear and rebuild
  TRUNCATE psn_leaderboard_cache;
  
  INSERT INTO psn_leaderboard_cache (user_id, display_name, avatar_url, platinum_count, total_games, updated_at)
  SELECT 
    p.id,
    p.psn_online_id,
    p.psn_avatar_url,
    COUNT(DISTINCT CASE WHEN a.psn_trophy_type = 'platinum' THEN ua.id END) as platinum_count,
    COUNT(DISTINCT a.game_title_id) as total_games,
    NOW()
  FROM profiles p
  INNER JOIN user_achievements ua ON ua.user_id = p.id
  INNER JOIN achievements a ON a.id = ua.achievement_id AND a.platform = 'psn'
  WHERE p.show_on_leaderboard = true
    AND p.psn_account_id IS NOT NULL
  GROUP BY p.id, p.psn_online_id, p.psn_avatar_url
  HAVING COUNT(DISTINCT CASE WHEN a.psn_trophy_type = 'platinum' THEN ua.id END) > 0;
END;
$$ LANGUAGE plpgsql;

-- Refresh Xbox Leaderboard Cache
CREATE OR REPLACE FUNCTION refresh_xbox_leaderboard_cache()
RETURNS void AS $$
BEGIN
  -- Clear and rebuild
  TRUNCATE xbox_leaderboard_cache;
  
  INSERT INTO xbox_leaderboard_cache (user_id, display_name, avatar_url, achievement_count, total_games, updated_at)
  SELECT 
    p.id,
    p.xbox_gamertag,
    p.xbox_avatar_url,
    COUNT(DISTINCT ua.id) as achievement_count,
    COUNT(DISTINCT a.game_title_id) as total_games,
    NOW()
  FROM profiles p
  INNER JOIN user_achievements ua ON ua.user_id = p.id
  INNER JOIN achievements a ON a.id = ua.achievement_id AND a.platform = 'xbox'
  WHERE p.show_on_leaderboard = true
    AND p.xbox_xuid IS NOT NULL
  GROUP BY p.id, p.xbox_gamertag, p.xbox_avatar_url
  HAVING COUNT(DISTINCT ua.id) > 0;
END;
$$ LANGUAGE plpgsql;

-- Refresh Steam Leaderboard Cache
CREATE OR REPLACE FUNCTION refresh_steam_leaderboard_cache()
RETURNS void AS $$
BEGIN
  -- Clear and rebuild
  TRUNCATE steam_leaderboard_cache;
  
  INSERT INTO steam_leaderboard_cache (user_id, display_name, avatar_url, achievement_count, total_games, updated_at)
  SELECT 
    p.id,
    COALESCE(p.steam_display_name, p.display_name),
    p.steam_avatar_url,
    COUNT(DISTINCT ua.id) as achievement_count,
    COUNT(DISTINCT a.game_title_id) as total_games,
    NOW()
  FROM profiles p
  INNER JOIN user_achievements ua ON ua.user_id = p.id
  INNER JOIN achievements a ON a.id = ua.achievement_id AND a.platform = 'steam'
  WHERE p.show_on_leaderboard = true
    AND p.steam_id IS NOT NULL
  GROUP BY p.id, p.steam_display_name, p.display_name, p.steam_avatar_url
  HAVING COUNT(DISTINCT ua.id) > 0;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- UPDATE EXISTING AUTO-REFRESH TO INCLUDE ALL PLATFORMS
-- ============================================================================

-- Drop old auto-refresh function if exists
DROP FUNCTION IF EXISTS auto_refresh_leaderboard_cache() CASCADE;

-- New unified auto-refresh for ALL leaderboards
CREATE OR REPLACE FUNCTION auto_refresh_all_leaderboards()
RETURNS void AS $$
BEGIN
  -- Refresh StatusXP leaderboard (already exists)
  REFRESH MATERIALIZED VIEW CONCURRENTLY leaderboard_cache;
  
  -- Refresh platform-specific leaderboards
  PERFORM refresh_psn_leaderboard_cache();
  PERFORM refresh_xbox_leaderboard_cache();
  PERFORM refresh_steam_leaderboard_cache();
END;
$$ LANGUAGE plpgsql;

-- Schedule auto-refresh every hour (replace existing cron job if it exists)
DO $$
BEGIN
  -- Try to unschedule old job if it exists
  PERFORM cron.unschedule('refresh-leaderboard-cache');
EXCEPTION
  WHEN OTHERS THEN
    -- Job doesn't exist, that's fine
    NULL;
END $$;

SELECT cron.schedule(
  'refresh-all-leaderboards',
  '0 * * * *', -- Every hour
  $$SELECT auto_refresh_all_leaderboards()$$
);

-- ============================================================================
-- TRIGGER: Auto-refresh when achievements sync
-- ============================================================================

CREATE OR REPLACE FUNCTION trigger_refresh_leaderboards_on_sync()
RETURNS TRIGGER AS $$
BEGIN
  -- Refresh all leaderboards after achievement sync completes
  PERFORM auto_refresh_all_leaderboards();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger if exists
DROP TRIGGER IF EXISTS refresh_leaderboards_after_achievement_sync ON user_achievements;

-- Create trigger on user_achievements table
CREATE TRIGGER refresh_leaderboards_after_achievement_sync
  AFTER INSERT OR UPDATE OR DELETE ON user_achievements
  FOR EACH STATEMENT
  EXECUTE FUNCTION trigger_refresh_leaderboards_on_sync();

-- Initial population
SELECT refresh_psn_leaderboard_cache();
SELECT refresh_xbox_leaderboard_cache();
SELECT refresh_steam_leaderboard_cache();
