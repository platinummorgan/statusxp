-- Add leaderboard rank tracking for movement indicators
-- This migration adds the ability to track and display rank changes over time

-- Create table to store leaderboard snapshots
CREATE TABLE IF NOT EXISTS public.leaderboard_history (
  user_id uuid NOT NULL,
  rank integer NOT NULL,
  total_statusxp bigint NOT NULL,
  total_game_entries integer DEFAULT 0,
  snapshot_at timestamp with time zone NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, snapshot_at)
);

ALTER TABLE public.leaderboard_history OWNER TO postgres;

COMMENT ON TABLE public.leaderboard_history IS 'Historical snapshots of leaderboard rankings for tracking rank changes over time';
COMMENT ON COLUMN public.leaderboard_history.rank IS 'User rank at time of snapshot';
COMMENT ON COLUMN public.leaderboard_history.total_statusxp IS 'Total StatusXP at time of snapshot';
COMMENT ON COLUMN public.leaderboard_history.snapshot_at IS 'When this snapshot was taken';

-- Create index for efficient queries
CREATE INDEX IF NOT EXISTS idx_leaderboard_history_user_snapshot ON public.leaderboard_history (user_id, snapshot_at DESC);
CREATE INDEX IF NOT EXISTS idx_leaderboard_history_snapshot_at ON public.leaderboard_history (snapshot_at DESC);

-- Function to create a leaderboard snapshot
CREATE OR REPLACE FUNCTION public.snapshot_leaderboard()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO public.leaderboard_history (user_id, rank, total_statusxp, total_game_entries, snapshot_at)
  SELECT 
    lc.user_id,
    ROW_NUMBER() OVER (ORDER BY lc.total_statusxp DESC)::integer as rank,
    lc.total_statusxp,
    lc.total_game_entries,
    now()
  FROM public.leaderboard_cache lc
  JOIN public.profiles p ON p.id = lc.user_id
  WHERE p.show_on_leaderboard = true
    AND lc.total_statusxp > 0;
END;
$$;

ALTER FUNCTION public.snapshot_leaderboard() OWNER TO postgres;

COMMENT ON FUNCTION public.snapshot_leaderboard() IS 'Creates a snapshot of current leaderboard rankings. Should be called daily via pg_cron.';

-- Function to get leaderboard with rank changes
CREATE OR REPLACE FUNCTION public.get_leaderboard_with_movement(
  limit_count integer DEFAULT 100,
  offset_count integer DEFAULT 0
)
RETURNS TABLE (
  user_id uuid,
  display_name text,
  avatar_url text,
  total_statusxp bigint,
  total_game_entries integer,
  current_rank bigint,
  previous_rank integer,
  rank_change integer,
  is_new boolean,
  preferred_display_platform text,
  psn_online_id text,
  psn_avatar_url text,
  xbox_gamertag text,
  xbox_avatar_url text,
  steam_display_name text,
  steam_avatar_url text
)
LANGUAGE plpgsql
AS $$
DECLARE
  latest_snapshot_time timestamp with time zone;
BEGIN
  -- Get the most recent snapshot time (excluding current moment)
  SELECT MAX(snapshot_at) INTO latest_snapshot_time
  FROM public.leaderboard_history
  WHERE snapshot_at < now() - INTERVAL '1 hour';  -- At least 1 hour old

  RETURN QUERY
  WITH current_ranks AS (
    SELECT 
      lc.user_id,
      ROW_NUMBER() OVER (ORDER BY lc.total_statusxp DESC) as rank,
      lc.total_statusxp,
      lc.total_game_entries
    FROM public.leaderboard_cache lc
    JOIN public.profiles p ON p.id = lc.user_id
    WHERE p.show_on_leaderboard = true
      AND lc.total_statusxp > 0
  ),
  previous_ranks AS (
    SELECT DISTINCT ON (lh.user_id)
      lh.user_id,
      lh.rank as prev_rank
    FROM public.leaderboard_history lh
    WHERE lh.snapshot_at = latest_snapshot_time
    ORDER BY lh.user_id
  )
  SELECT 
    cr.user_id,
    COALESCE(p.display_name, p.username, 'Player'::text) as display_name,
    COALESCE(
      CASE p.preferred_display_platform
        WHEN 'psn' THEN p.psn_avatar_url
        WHEN 'xbox' THEN p.xbox_avatar_url
        WHEN 'steam' THEN p.steam_avatar_url
        ELSE p.avatar_url
      END,
      p.avatar_url
    ) as avatar_url,
    cr.total_statusxp,
    cr.total_game_entries,
    cr.rank::bigint as current_rank,
    pr.prev_rank as previous_rank,
    CASE 
      WHEN pr.prev_rank IS NULL THEN 0
      ELSE (pr.prev_rank - cr.rank::integer)
    END as rank_change,
    (pr.prev_rank IS NULL) as is_new,
    p.preferred_display_platform,
    p.psn_online_id,
    p.psn_avatar_url,
    p.xbox_gamertag,
    p.xbox_avatar_url,
    p.steam_display_name,
    p.steam_avatar_url
  FROM current_ranks cr
  JOIN public.profiles p ON p.id = cr.user_id
  LEFT JOIN previous_ranks pr ON pr.user_id = cr.user_id
  ORDER BY cr.rank
  LIMIT limit_count
  OFFSET offset_count;
END;
$$;

ALTER FUNCTION public.get_leaderboard_with_movement(integer, integer) OWNER TO postgres;

COMMENT ON FUNCTION public.get_leaderboard_with_movement(integer, integer) IS 'Returns leaderboard with rank change indicators. Positive rank_change = moved up, negative = moved down, 0 = new or no change.';

-- Grant permissions
GRANT ALL ON TABLE public.leaderboard_history TO anon;
GRANT ALL ON TABLE public.leaderboard_history TO authenticated;
GRANT ALL ON TABLE public.leaderboard_history TO service_role;

GRANT ALL ON FUNCTION public.snapshot_leaderboard() TO anon;
GRANT ALL ON FUNCTION public.snapshot_leaderboard() TO authenticated;
GRANT ALL ON FUNCTION public.snapshot_leaderboard() TO service_role;

GRANT ALL ON FUNCTION public.get_leaderboard_with_movement(integer, integer) TO anon;
GRANT ALL ON FUNCTION public.get_leaderboard_with_movement(integer, integer) TO authenticated;
GRANT ALL ON FUNCTION public.get_leaderboard_with_movement(integer, integer) TO service_role;

-- Create initial snapshot
SELECT public.snapshot_leaderboard();

-- Schedule daily snapshots (requires pg_cron extension)
-- Run at 4 AM UTC daily
SELECT cron.schedule(
  'daily-leaderboard-snapshot',
  '0 4 * * *',
  'SELECT public.snapshot_leaderboard();'
);
