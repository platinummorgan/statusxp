-- Add Potential Stats to All Leaderboard Caches
-- Run in Supabase SQL Editor: https://supabase.com/dashboard/project/ksriqcmumjkemtfjuedm/sql/new

-- ============================================================================
-- 1. UPDATE XBOX CACHE - Add potential_gamerscore
-- ============================================================================

-- Add column to xbox_leaderboard_cache
ALTER TABLE xbox_leaderboard_cache 
ADD COLUMN IF NOT EXISTS potential_gamerscore bigint DEFAULT 0;

-- Update the view to calculate potential gamerscore
CREATE OR REPLACE VIEW xbox_leaderboard_cache_v2 AS
SELECT 
  p.id as user_id,
  COALESCE(p.xbox_gamertag, p.display_name, p.username, 'Player') as display_name,
  p.xbox_avatar_url as avatar_url,
  COALESCE(SUM(ug.gamerscore), 0) as gamerscore,
  COALESCE(SUM(ug.max_gamerscore), 0) as potential_gamerscore,
  COUNT(DISTINCT CASE WHEN ug.achievement_count > 0 THEN ug.game_title_id END) as achievement_count,
  COUNT(DISTINCT ug.game_title_id) as total_games,
  now() as updated_at
FROM profiles p
LEFT JOIN user_games ug ON ug.user_id = p.id AND ug.platform = 'xbox'
WHERE p.show_on_leaderboard = true
GROUP BY p.id, p.xbox_gamertag, p.display_name, p.username, p.xbox_avatar_url
HAVING COUNT(DISTINCT ug.game_title_id) > 0
ORDER BY gamerscore DESC, total_games DESC;

-- ============================================================================
-- 2. UPDATE STEAM CACHE - Add potential_achievements
-- ============================================================================

-- Add column to steam_leaderboard_cache
ALTER TABLE steam_leaderboard_cache 
ADD COLUMN IF NOT EXISTS potential_achievements bigint DEFAULT 0;

-- Update the view to calculate potential achievements
CREATE OR REPLACE VIEW steam_leaderboard_cache_v2 AS
SELECT 
  p.id as user_id,
  COALESCE(p.steam_display_name, p.display_name, p.username, 'Player') as display_name,
  p.steam_avatar_url as avatar_url,
  COALESCE(SUM(ug.achievement_count), 0) as achievement_count,
  COALESCE(SUM(ug.total_achievements), 0) as potential_achievements,
  COUNT(DISTINCT ug.game_title_id) as total_games,
  now() as updated_at
FROM profiles p
LEFT JOIN user_games ug ON ug.user_id = p.id AND ug.platform = 'steam'
WHERE p.show_on_leaderboard = true
GROUP BY p.id, p.steam_display_name, p.display_name, p.username, p.steam_avatar_url
HAVING COUNT(DISTINCT ug.game_title_id) > 0
ORDER BY achievement_count DESC, total_games DESC;

-- ============================================================================
-- 3. UPDATE STATUSXP CACHE - Add potential_statusxp  
-- ============================================================================

-- Add column to leaderboard_cache
ALTER TABLE leaderboard_cache 
ADD COLUMN IF NOT EXISTS potential_statusxp bigint DEFAULT 0;

-- Add columns for display
ALTER TABLE leaderboard_cache
ADD COLUMN IF NOT EXISTS display_name text,
ADD COLUMN IF NOT EXISTS avatar_url text;

-- Update the view to calculate potential StatusXP
CREATE OR REPLACE VIEW leaderboard_cache_v2 AS
SELECT 
  p.id as user_id,
  COALESCE(p.display_name, p.username, 'Player') as display_name,
  COALESCE(p.psn_avatar_url, p.xbox_avatar_url, p.steam_avatar_url) as avatar_url,
  COALESCE(SUM(ug.statusxp), 0) as total_statusxp,
  COALESCE(SUM(ug.max_statusxp), 0) as potential_statusxp,
  COUNT(DISTINCT ug.game_title_id) as total_game_entries,
  now() as last_updated
FROM profiles p
LEFT JOIN user_games ug ON ug.user_id = p.id
WHERE p.show_on_leaderboard = true
GROUP BY p.id, p.display_name, p.username, p.psn_avatar_url, p.xbox_avatar_url, p.steam_avatar_url
HAVING COUNT(DISTINCT ug.game_title_id) > 0
ORDER BY total_statusxp DESC;

-- ============================================================================
-- 4. RECREATE PSN MATERIALIZED VIEW with trophy breakdown (already has it)
-- ============================================================================

-- PSN materialized view already has bronze, silver, gold, platinum counts
-- Just verify it exists
SELECT 
  'PSN cache has ' || COUNT(*) || ' users' as status,
  SUM(platinum_count) as total_platinums,
  SUM(gold_count) as total_golds
FROM psn_leaderboard_cache
LIMIT 1;

-- ============================================================================
-- 5. UPDATE RPC FUNCTIONS (simplified - use cache columns directly)
-- ============================================================================

-- Drop and recreate Xbox function with potential_gamerscore
DROP FUNCTION IF EXISTS get_xbox_leaderboard_with_movement(integer, integer);

CREATE FUNCTION get_xbox_leaderboard_with_movement(
  limit_count integer DEFAULT 100,
  offset_count integer DEFAULT 0
)
RETURNS TABLE (
  user_id uuid,
  display_name text,
  avatar_url text,
  gamerscore bigint,
  potential_gamerscore bigint,
  achievement_count bigint,
  total_games bigint,
  previous_rank integer,
  rank_change integer,
  is_new boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  WITH current_leaderboard AS (
    SELECT 
      lc.user_id,
      lc.display_name,
      lc.avatar_url,
      lc.gamerscore,
      lc.potential_gamerscore,
      lc.achievement_count,
      lc.total_games,
      ROW_NUMBER() OVER (ORDER BY lc.gamerscore DESC, lc.total_games DESC) as current_rank
    FROM xbox_leaderboard_cache lc
  ),
  latest_snapshot AS (
    SELECT DISTINCT ON (h.user_id)
      h.user_id,
      h.rank as prev_rank
    FROM xbox_leaderboard_history h
    WHERE h.snapshot_at < now() - INTERVAL '1 hour'
    ORDER BY h.user_id, h.snapshot_at DESC
  )
  SELECT 
    cl.user_id,
    cl.display_name,
    cl.avatar_url,
    cl.gamerscore,
    cl.potential_gamerscore,
    cl.achievement_count,
    cl.total_games,
    ls.prev_rank as previous_rank,
    CASE 
      WHEN ls.prev_rank IS NULL THEN 0
      ELSE (ls.prev_rank - cl.current_rank::integer)
    END as rank_change,
    (ls.prev_rank IS NULL) as is_new
  FROM current_leaderboard cl
  LEFT JOIN latest_snapshot ls ON ls.user_id = cl.user_id
  ORDER BY cl.current_rank
  LIMIT limit_count
  OFFSET offset_count;
END;
$$;

-- Drop and recreate Steam function with potential_achievements
DROP FUNCTION IF EXISTS get_steam_leaderboard_with_movement(integer, integer);

CREATE FUNCTION get_steam_leaderboard_with_movement(
  limit_count integer DEFAULT 100,
  offset_count integer DEFAULT 0
)
RETURNS TABLE (
  user_id uuid,
  display_name text,
  avatar_url text,
  achievement_count bigint,
  potential_achievements bigint,
  total_games bigint,
  previous_rank integer,
  rank_change integer,
  is_new boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  WITH current_leaderboard AS (
    SELECT 
      lc.user_id,
      lc.display_name,
      lc.avatar_url,
      lc.achievement_count,
      lc.potential_achievements,
      lc.total_games,
      ROW_NUMBER() OVER (ORDER BY lc.achievement_count DESC, lc.total_games DESC) as current_rank
    FROM steam_leaderboard_cache lc
  ),
  latest_snapshot AS (
    SELECT DISTINCT ON (h.user_id)
      h.user_id,
      h.rank as prev_rank
    FROM steam_leaderboard_history h
    WHERE h.snapshot_at < now() - INTERVAL '1 hour'
    ORDER BY h.user_id, h.snapshot_at DESC
  )
  SELECT 
    cl.user_id,
    cl.display_name,
    cl.avatar_url,
    cl.achievement_count,
    cl.potential_achievements,
    cl.total_games,
    ls.prev_rank as previous_rank,
    CASE 
      WHEN ls.prev_rank IS NULL THEN 0
      ELSE (ls.prev_rank - cl.current_rank::integer)
    END as rank_change,
    (ls.prev_rank IS NULL) as is_new
  FROM current_leaderboard cl
  LEFT JOIN latest_snapshot ls ON ls.user_id = cl.user_id
  ORDER BY cl.current_rank
  LIMIT limit_count
  OFFSET offset_count;
END;
$$;

-- Drop and recreate StatusXP function with potential_statusxp
DROP FUNCTION IF EXISTS get_leaderboard_with_movement(integer, integer);

CREATE FUNCTION get_leaderboard_with_movement(
  limit_count integer DEFAULT 100,
  offset_count integer DEFAULT 0
)
RETURNS TABLE (
  user_id uuid,
  display_name text,
  avatar_url text,
  total_statusxp bigint,
  potential_statusxp bigint,
  total_game_entries integer,
  previous_rank integer,
  rank_change integer,
  is_new boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  WITH current_leaderboard AS (
    SELECT 
      lc.user_id,
      lc.display_name,
      lc.avatar_url,
      lc.total_statusxp,
      lc.potential_statusxp,
      lc.total_game_entries,
      ROW_NUMBER() OVER (ORDER BY lc.total_statusxp DESC) as current_rank
    FROM leaderboard_cache lc
  ),
  latest_snapshot AS (
    SELECT DISTINCT ON (h.user_id)
      h.user_id,
      h.rank as prev_rank
    FROM leaderboard_history h
    WHERE h.snapshot_at < now() - INTERVAL '1 hour'
    ORDER BY h.user_id, h.snapshot_at DESC
  )
  SELECT 
    cl.user_id,
    cl.display_name,
    cl.avatar_url,
    cl.total_statusxp,
    cl.potential_statusxp,
    cl.total_game_entries,
    ls.prev_rank as previous_rank,
    CASE 
      WHEN ls.prev_rank IS NULL THEN 0
      ELSE (ls.prev_rank - cl.current_rank::integer)
    END as rank_change,
    (ls.prev_rank IS NULL) as is_new
  FROM current_leaderboard cl
  LEFT JOIN latest_snapshot ls ON ls.user_id = cl.user_id
  ORDER BY cl.current_rank
  LIMIT limit_count
  OFFSET offset_count;
END;
$$;

-- Drop and recreate PSN function with trophy breakdown
DROP FUNCTION IF EXISTS get_psn_leaderboard_with_movement(integer, integer);

CREATE FUNCTION get_psn_leaderboard_with_movement(
  limit_count integer DEFAULT 100,
  offset_count integer DEFAULT 0
)
RETURNS TABLE (
  user_id uuid,
  display_name text,
  avatar_url text,
  platinum_count bigint,
  gold_count bigint,
  silver_count bigint,
  bronze_count bigint,
  total_trophies bigint,
  total_games bigint,
  previous_rank integer,
  rank_change integer,
  is_new boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  WITH current_leaderboard AS (
    SELECT 
      lc.user_id,
      lc.display_name,
      lc.avatar_url,
      lc.platinum_count,
      lc.gold_count,
      lc.silver_count,
      lc.bronze_count,
      lc.total_trophies,
      lc.total_games,
      ROW_NUMBER() OVER (ORDER BY lc.platinum_count DESC, lc.gold_count DESC, lc.silver_count DESC) as current_rank
    FROM psn_leaderboard_cache lc
  ),
  latest_snapshot AS (
    SELECT DISTINCT ON (h.user_id)
      h.user_id,
      h.rank as prev_rank
    FROM psn_leaderboard_history h
    WHERE h.snapshot_at < now() - INTERVAL '1 hour'
    ORDER BY h.user_id, h.snapshot_at DESC
  )
  SELECT 
    cl.user_id,
    cl.display_name,
    cl.avatar_url,
    cl.platinum_count,
    cl.gold_count,
    cl.silver_count,
    cl.bronze_count,
    cl.total_trophies,
    cl.total_games,
    ls.prev_rank as previous_rank,
    CASE 
      WHEN ls.prev_rank IS NULL THEN 0
      ELSE (ls.prev_rank - cl.current_rank::integer)
    END as rank_change,
    (ls.prev_rank IS NULL) as is_new
  FROM current_leaderboard cl
  LEFT JOIN latest_snapshot ls ON ls.user_id = cl.user_id
  ORDER BY cl.current_rank
  LIMIT limit_count
  OFFSET offset_count;
END;
$$;

-- ============================================================================
-- 6. TEST ALL FUNCTIONS
-- ============================================================================

-- Test PSN (should show trophy breakdown)
SELECT 
  display_name,
  platinum_count,
  gold_count,
  silver_count,
  bronze_count,
  is_new
FROM get_psn_leaderboard_with_movement(3, 0);

-- Test Xbox (should show gamerscore | potential)
SELECT 
  display_name,
  gamerscore,
  potential_gamerscore,
  is_new
FROM get_xbox_leaderboard_with_movement(3, 0);

-- Test Steam (should show achievements | potential)
SELECT 
  display_name,
  achievement_count,
  potential_achievements,
  is_new
FROM get_steam_leaderboard_with_movement(3, 0);

-- Test StatusXP (should show statusxp | potential)
SELECT 
  display_name,
  total_statusxp,
  potential_statusxp,
  is_new
FROM get_leaderboard_with_movement(3, 0);
