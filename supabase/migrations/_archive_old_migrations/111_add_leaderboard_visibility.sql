-- Migration: 111_add_leaderboard_visibility.sql
-- Created: 2025-12-30
-- Description: Add privacy control for leaderboard visibility

-- Add column to profiles
ALTER TABLE profiles 
  ADD COLUMN IF NOT EXISTS show_on_leaderboard BOOLEAN DEFAULT true;

-- Add index for faster leaderboard queries
CREATE INDEX IF NOT EXISTS idx_profiles_show_on_leaderboard 
  ON profiles(show_on_leaderboard);

-- Add comment
COMMENT ON COLUMN profiles.show_on_leaderboard IS 
  'Privacy setting: whether user appears on public leaderboards (default: true)';

-- ============================================================================
-- OPTIMIZED LEADERBOARD FUNCTIONS (Fast database-side aggregation)
-- ============================================================================

-- Platinum Leaderboard Function
CREATE OR REPLACE FUNCTION get_platinum_leaderboard(limit_count INT DEFAULT 100)
RETURNS TABLE(
  user_id UUID,
  display_name TEXT,
  avatar_url TEXT,
  score BIGINT,
  games_count BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.psn_online_id,
    p.psn_avatar_url,
    COUNT(DISTINCT CASE WHEN a.psn_trophy_type = 'platinum' THEN ua.id END) as platinum_count,
    COUNT(DISTINCT ua.achievement_id) as total_games
  FROM profiles p
  INNER JOIN user_achievements ua ON ua.user_id = p.id
  INNER JOIN achievements a ON a.id = ua.achievement_id AND a.platform = 'psn'
  WHERE p.show_on_leaderboard = true
    AND p.psn_account_id IS NOT NULL
  GROUP BY p.id, p.psn_online_id, p.psn_avatar_url
  HAVING COUNT(DISTINCT CASE WHEN a.psn_trophy_type = 'platinum' THEN ua.id END) > 0
  ORDER BY platinum_count DESC, total_games DESC
  LIMIT limit_count;
END;
$$ LANGUAGE plpgsql STABLE;

-- Xbox Leaderboard Function
CREATE OR REPLACE FUNCTION get_xbox_leaderboard(limit_count INT DEFAULT 100)
RETURNS TABLE(
  user_id UUID,
  display_name TEXT,
  avatar_url TEXT,
  score BIGINT,
  games_count BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.xbox_gamertag,
    p.xbox_avatar_url,
    COUNT(DISTINCT ua.id) as achievement_count,
    COUNT(DISTINCT a.game_title_id) as total_games
  FROM profiles p
  INNER JOIN user_achievements ua ON ua.user_id = p.id
  INNER JOIN achievements a ON a.id = ua.achievement_id AND a.platform = 'xbox'
  WHERE p.show_on_leaderboard = true
    AND p.xbox_xuid IS NOT NULL
  GROUP BY p.id, p.xbox_gamertag, p.xbox_avatar_url
  HAVING COUNT(DISTINCT ua.id) > 0
  ORDER BY achievement_count DESC, total_games DESC
  LIMIT limit_count;
END;
$$ LANGUAGE plpgsql STABLE;

-- Steam Leaderboard Function
CREATE OR REPLACE FUNCTION get_steam_leaderboard(limit_count INT DEFAULT 100)
RETURNS TABLE(
  user_id UUID,
  display_name TEXT,
  avatar_url TEXT,
  score BIGINT,
  games_count BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    COALESCE(p.steam_display_name, p.display_name),
    p.steam_avatar_url,
    COUNT(DISTINCT ua.id) as achievement_count,
    COUNT(DISTINCT a.game_title_id) as total_games
  FROM profiles p
  INNER JOIN user_achievements ua ON ua.user_id = p.id
  INNER JOIN achievements a ON a.id = ua.achievement_id AND a.platform = 'steam'
  WHERE p.show_on_leaderboard = true
    AND p.steam_id IS NOT NULL
  GROUP BY p.id, p.steam_display_name, p.display_name, p.steam_avatar_url
  HAVING COUNT(DISTINCT ua.id) > 0
  ORDER BY achievement_count DESC, total_games DESC
  LIMIT limit_count;
END;
$$ LANGUAGE plpgsql STABLE;
