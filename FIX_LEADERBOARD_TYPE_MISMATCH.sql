-- Fix type mismatch in platform leaderboard RPC functions
-- Run in Supabase SQL Editor: https://supabase.com/dashboard/project/ksriqcmumjkemtfjuedm/sql/new

-- Drop existing functions first (required when changing return type)
DROP FUNCTION IF EXISTS get_psn_leaderboard_with_movement(integer, integer);
DROP FUNCTION IF EXISTS get_xbox_leaderboard_with_movement(integer, integer);
DROP FUNCTION IF EXISTS get_steam_leaderboard_with_movement(integer, integer);

-- Fix PSN leaderboard function - change integer to bigint for counts
CREATE FUNCTION get_psn_leaderboard_with_movement(
  limit_count integer DEFAULT 100,
  offset_count integer DEFAULT 0
)
RETURNS TABLE (
  user_id uuid,
  display_name text,
  avatar_url text,
  platinum_count bigint,
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

-- Fix Xbox leaderboard function - change integer to bigint for counts
CREATE FUNCTION get_xbox_leaderboard_with_movement(
  limit_count integer DEFAULT 100,
  offset_count integer DEFAULT 0
)
RETURNS TABLE (
  user_id uuid,
  display_name text,
  avatar_url text,
  gamerscore bigint,
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

-- Fix Steam leaderboard function - change integer to bigint for counts
CREATE FUNCTION get_steam_leaderboard_with_movement(
  limit_count integer DEFAULT 100,
  offset_count integer DEFAULT 0
)
RETURNS TABLE (
  user_id uuid,
  display_name text,
  avatar_url text,
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
      lc.achievement_count,
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

-- Test the fixed functions
SELECT * FROM get_psn_leaderboard_with_movement(5, 0);
SELECT * FROM get_xbox_leaderboard_with_movement(5, 0);
SELECT * FROM get_steam_leaderboard_with_movement(5, 0);
