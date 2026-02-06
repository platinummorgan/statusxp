-- ============================================================================
-- Add possible trophy counts to PSN leaderboard RPC function
-- ============================================================================

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
  possible_platinum bigint,
  possible_gold bigint,
  possible_silver bigint,
  possible_bronze bigint,
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
      lc.possible_platinum,
      lc.possible_gold,
      lc.possible_silver,
      lc.possible_bronze,
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
    cl.possible_platinum,
    cl.possible_gold,
    cl.possible_silver,
    cl.possible_bronze,
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

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_psn_leaderboard_with_movement(integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION get_psn_leaderboard_with_movement(integer, integer) TO anon;
