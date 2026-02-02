-- Enhance Leaderboard RPC Functions with Detailed Stats
-- Run in Supabase SQL Editor: https://supabase.com/dashboard/project/ksriqcmumjkemtfjuedm/sql/new

-- Drop existing functions
DROP FUNCTION IF EXISTS get_psn_leaderboard_with_movement(integer, integer);
DROP FUNCTION IF EXISTS get_xbox_leaderboard_with_movement(integer, integer);
DROP FUNCTION IF EXISTS get_steam_leaderboard_with_movement(integer, integer);
DROP FUNCTION IF EXISTS get_leaderboard_with_movement(integer, integer);

-- ============================================================================
-- PSN: Add trophy breakdown (Platinum | Gold | Silver | Bronze)
-- ============================================================================
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
-- XBOX: Add current vs potential gamerscore
-- ============================================================================
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

-- ============================================================================
-- STEAM: Add current vs potential achievements
-- ============================================================================
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

-- ============================================================================
-- STATUSXP: Add current vs potential StatusXP
-- ============================================================================
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

-- Test all functions
SELECT * FROM get_psn_leaderboard_with_movement(3, 0);
SELECT * FROM get_xbox_leaderboard_with_movement(3, 0);
SELECT * FROM get_steam_leaderboard_with_movement(3, 0);
SELECT * FROM get_leaderboard_with_movement(3, 0);
