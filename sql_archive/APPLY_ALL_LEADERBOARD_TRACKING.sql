-- Run this in Supabase SQL Editor to add rank tracking to all leaderboards
-- https://supabase.com/dashboard/project/ksriqcmumjkemtfjuedm/sql/new

-- ============================================================================
-- PSN PLATINUM LEADERBOARD HISTORY
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.psn_leaderboard_history (
  user_id uuid NOT NULL,
  snapshot_at timestamptz NOT NULL DEFAULT now(),
  rank integer NOT NULL,
  platinum_count integer NOT NULL,
  total_games integer NOT NULL,
  PRIMARY KEY (user_id, snapshot_at)
);

CREATE INDEX IF NOT EXISTS idx_psn_leaderboard_history_snapshot 
  ON psn_leaderboard_history(snapshot_at DESC);

CREATE INDEX IF NOT EXISTS idx_psn_leaderboard_history_user 
  ON psn_leaderboard_history(user_id, snapshot_at DESC);

-- Function to snapshot PSN platinum leaderboard
CREATE OR REPLACE FUNCTION snapshot_psn_leaderboard()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO psn_leaderboard_history (user_id, snapshot_at, rank, platinum_count, total_games)
  SELECT 
    user_id,
    now(),
    ROW_NUMBER() OVER (ORDER BY platinum_count DESC, gold_count DESC, silver_count DESC) as rank,
    platinum_count,
    total_games
  FROM psn_leaderboard_cache
  ORDER BY rank;
  
  RAISE NOTICE 'PSN leaderboard snapshot created at %', now();
END;
$$;

-- Function to get PSN leaderboard with movement
CREATE OR REPLACE FUNCTION get_psn_leaderboard_with_movement(
  limit_count integer DEFAULT 100,
  offset_count integer DEFAULT 0
)
RETURNS TABLE (
  user_id uuid,
  display_name text,
  avatar_url text,
  platinum_count integer,
  total_games integer,
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

-- ============================================================================
-- XBOX LEADERBOARD HISTORY
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.xbox_leaderboard_history (
  user_id uuid NOT NULL,
  snapshot_at timestamptz NOT NULL DEFAULT now(),
  rank integer NOT NULL,
  gamerscore integer NOT NULL,
  achievement_count integer NOT NULL,
  total_games integer NOT NULL,
  PRIMARY KEY (user_id, snapshot_at)
);

CREATE INDEX IF NOT EXISTS idx_xbox_leaderboard_history_snapshot 
  ON xbox_leaderboard_history(snapshot_at DESC);

CREATE INDEX IF NOT EXISTS idx_xbox_leaderboard_history_user 
  ON xbox_leaderboard_history(user_id, snapshot_at DESC);

-- Function to snapshot Xbox leaderboard
CREATE OR REPLACE FUNCTION snapshot_xbox_leaderboard()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO xbox_leaderboard_history (user_id, snapshot_at, rank, gamerscore, achievement_count, total_games)
  SELECT 
    user_id,
    now(),
    ROW_NUMBER() OVER (ORDER BY gamerscore DESC, total_games DESC) as rank,
    gamerscore,
    achievement_count,
    total_games
  FROM xbox_leaderboard_cache
  ORDER BY rank;
  
  RAISE NOTICE 'Xbox leaderboard snapshot created at %', now();
END;
$$;

-- Function to get Xbox leaderboard with movement
CREATE OR REPLACE FUNCTION get_xbox_leaderboard_with_movement(
  limit_count integer DEFAULT 100,
  offset_count integer DEFAULT 0
)
RETURNS TABLE (
  user_id uuid,
  display_name text,
  avatar_url text,
  gamerscore integer,
  achievement_count integer,
  total_games integer,
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

-- ============================================================================
-- STEAM LEADERBOARD HISTORY
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.steam_leaderboard_history (
  user_id uuid NOT NULL,
  snapshot_at timestamptz NOT NULL DEFAULT now(),
  rank integer NOT NULL,
  achievement_count integer NOT NULL,
  total_games integer NOT NULL,
  PRIMARY KEY (user_id, snapshot_at)
);

CREATE INDEX IF NOT EXISTS idx_steam_leaderboard_history_snapshot 
  ON steam_leaderboard_history(snapshot_at DESC);

CREATE INDEX IF NOT EXISTS idx_steam_leaderboard_history_user 
  ON steam_leaderboard_history(user_id, snapshot_at DESC);

-- Function to snapshot Steam leaderboard
CREATE OR REPLACE FUNCTION snapshot_steam_leaderboard()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO steam_leaderboard_history (user_id, snapshot_at, rank, achievement_count, total_games)
  SELECT 
    user_id,
    now(),
    ROW_NUMBER() OVER (ORDER BY achievement_count DESC, total_games DESC) as rank,
    achievement_count,
    total_games
  FROM steam_leaderboard_cache
  ORDER BY rank;
  
  RAISE NOTICE 'Steam leaderboard snapshot created at %', now();
END;
$$;

-- Function to get Steam leaderboard with movement
CREATE OR REPLACE FUNCTION get_steam_leaderboard_with_movement(
  limit_count integer DEFAULT 100,
  offset_count integer DEFAULT 0
)
RETURNS TABLE (
  user_id uuid,
  display_name text,
  avatar_url text,
  achievement_count integer,
  total_games integer,
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

-- ============================================================================
-- PERMISSIONS
-- ============================================================================

GRANT SELECT ON psn_leaderboard_history TO authenticated;
GRANT SELECT ON psn_leaderboard_history TO anon;

GRANT SELECT ON xbox_leaderboard_history TO authenticated;
GRANT SELECT ON xbox_leaderboard_history TO anon;

GRANT SELECT ON steam_leaderboard_history TO authenticated;
GRANT SELECT ON steam_leaderboard_history TO anon;

-- ============================================================================
-- SCHEDULED SNAPSHOTS
-- ============================================================================

-- Schedule PSN leaderboard snapshots (daily at 4 AM UTC)
SELECT cron.schedule(
  'snapshot_psn_leaderboard',
  '0 4 * * *',
  $$SELECT snapshot_psn_leaderboard()$$
);

-- Schedule Xbox leaderboard snapshots (daily at 4 AM UTC)
SELECT cron.schedule(
  'snapshot_xbox_leaderboard',
  '0 4 * * *',
  $$SELECT snapshot_xbox_leaderboard()$$
);

-- Schedule Steam leaderboard snapshots (daily at 4 AM UTC)
SELECT cron.schedule(
  'snapshot_steam_leaderboard',
  '0 4 * * *',
  $$SELECT snapshot_steam_leaderboard()$$
);

-- ============================================================================
-- INITIAL SNAPSHOTS
-- ============================================================================

-- Create initial snapshots for all three platforms
SELECT snapshot_psn_leaderboard();
SELECT snapshot_xbox_leaderboard();
SELECT snapshot_steam_leaderboard();

-- ============================================================================
-- VERIFY IT WORKED
-- ============================================================================

-- Check PSN snapshots
SELECT 
  'PSN' as platform,
  COUNT(*) as users,
  MAX(platinum_count) as max_score
FROM psn_leaderboard_history;

-- Check Xbox snapshots
SELECT 
  'Xbox' as platform,
  COUNT(*) as users,
  MAX(gamerscore) as max_score
FROM xbox_leaderboard_history;

-- Check Steam snapshots
SELECT 
  'Steam' as platform,
  COUNT(*) as users,
  MAX(achievement_count) as max_score
FROM steam_leaderboard_history;

-- Check cron jobs
SELECT 
  jobid,
  jobname,
  schedule,
  active
FROM cron.job
WHERE jobname LIKE 'snapshot_%_leaderboard'
ORDER BY jobname;
