-- Hotfix: Steam all-time leaderboard timeouts
-- Rebuild Steam leaderboard objects on top of user_progress (fast aggregate path)
-- so we avoid expensive joins through user_achievements + achievements.

BEGIN;

-- ---------------------------------------------------------------------------
-- Performance index for Steam aggregate scans
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_user_progress_steam_leaderboard
  ON public.user_progress (user_id, platform_game_id)
  INCLUDE (achievements_earned, total_achievements)
  WHERE platform_id = 4 AND achievements_earned > 0;

-- ---------------------------------------------------------------------------
-- Ensure anon/auth users can read leaderboard-eligible user_progress rows
-- (used by direct view fallback from client)
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "Anyone can view progress for leaderboard users" ON public.user_progress;
CREATE POLICY "Anyone can view progress for leaderboard users"
  ON public.user_progress
  FOR SELECT
  TO anon, authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.id = user_progress.user_id
        AND p.show_on_leaderboard = true
    )
  );

-- ---------------------------------------------------------------------------
-- Fast fallback view for Steam all-time leaderboard
-- ---------------------------------------------------------------------------
DROP VIEW IF EXISTS public.steam_leaderboard_cache CASCADE;
CREATE VIEW public.steam_leaderboard_cache
WITH (security_invoker = true) AS
SELECT
  up.user_id,
  COALESCE(p.steam_display_name, p.display_name, p.username, 'Player') AS display_name,
  p.steam_avatar_url AS avatar_url,
  SUM(GREATEST(COALESCE(up.achievements_earned, 0), 0))::integer AS achievement_count,
  SUM(GREATEST(COALESCE(up.total_achievements, 0), 0))::integer AS potential_achievements,
  COUNT(DISTINCT up.platform_game_id)::integer AS total_games,
  now() AS updated_at
FROM public.user_progress up
JOIN public.profiles p ON p.id = up.user_id
WHERE up.platform_id = 4
  AND COALESCE(up.achievements_earned, 0) > 0
  AND p.show_on_leaderboard = true
GROUP BY
  up.user_id,
  p.steam_display_name,
  p.display_name,
  p.username,
  p.steam_avatar_url;

GRANT SELECT ON public.steam_leaderboard_cache TO anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Steam movement RPC using the fast view
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.steam_leaderboard_history (
  user_id uuid NOT NULL,
  snapshot_at timestamptz NOT NULL DEFAULT now(),
  rank integer NOT NULL,
  achievement_count integer NOT NULL,
  total_games integer NOT NULL,
  PRIMARY KEY (user_id, snapshot_at)
);

CREATE INDEX IF NOT EXISTS idx_steam_leaderboard_history_snapshot
  ON public.steam_leaderboard_history(snapshot_at DESC);

CREATE INDEX IF NOT EXISTS idx_steam_leaderboard_history_user
  ON public.steam_leaderboard_history(user_id, snapshot_at DESC);

DROP FUNCTION IF EXISTS public.get_steam_leaderboard_with_movement(integer, integer);

CREATE FUNCTION public.get_steam_leaderboard_with_movement(
  limit_count integer DEFAULT 100,
  offset_count integer DEFAULT 0
)
RETURNS TABLE(
  user_id uuid,
  display_name text,
  avatar_url text,
  achievement_count integer,
  potential_achievements integer,
  total_games integer,
  previous_rank integer,
  rank_change integer,
  is_new boolean
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
SET statement_timeout = '25s'
AS $$
WITH current_leaderboard AS (
  SELECT
    slc.user_id,
    slc.display_name,
    slc.avatar_url,
    slc.achievement_count::integer AS achievement_count,
    slc.potential_achievements::integer AS potential_achievements,
    slc.total_games::integer AS total_games,
    ROW_NUMBER() OVER (
      ORDER BY slc.achievement_count DESC, slc.total_games DESC, slc.user_id ASC
    )::integer AS current_rank
  FROM public.steam_leaderboard_cache slc
),
latest_snapshot AS (
  SELECT DISTINCT ON (h.user_id)
    h.user_id,
    h.rank::integer AS prev_rank
  FROM public.steam_leaderboard_history h
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
  ls.prev_rank AS previous_rank,
  CASE
    WHEN ls.prev_rank IS NULL THEN 0
    ELSE ls.prev_rank - cl.current_rank
  END AS rank_change,
  (ls.prev_rank IS NULL) AS is_new
FROM current_leaderboard cl
LEFT JOIN latest_snapshot ls ON ls.user_id = cl.user_id
ORDER BY cl.current_rank
LIMIT GREATEST(limit_count, 0)
OFFSET GREATEST(offset_count, 0);
$$;

REVOKE ALL ON FUNCTION public.get_steam_leaderboard_with_movement(integer, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_steam_leaderboard_with_movement(integer, integer)
  TO anon, authenticated, service_role;

COMMIT;
