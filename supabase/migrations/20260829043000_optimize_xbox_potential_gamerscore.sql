-- Avoid timing out the Xbox leaderboard while calculating possible Gamerscore.
-- Xbox sync persists each title's authoritative maximum in user_progress.metadata
-- as max_gamerscore (with max_score retained as a legacy fallback), so joining
-- every progress row to the full achievements catalog is redundant and costly.

BEGIN;

CREATE INDEX IF NOT EXISTS idx_user_progress_xbox_leaderboard
  ON public.user_progress (user_id, platform_game_id)
  INCLUDE (current_score, metadata)
  WHERE platform_id IN (10, 11, 12);

CREATE OR REPLACE VIEW public.xbox_leaderboard_cache
WITH (security_invoker = true) AS
WITH xbox_user_stats AS (
  SELECT
    up.user_id,
    SUM(COALESCE(up.current_score, 0))::bigint AS total_gamerscore,
    SUM(
      CASE
        WHEN COALESCE(up.metadata->>'max_gamerscore', '') ~ '^[0-9]+$'
          THEN (up.metadata->>'max_gamerscore')::bigint
        WHEN COALESCE(up.metadata->>'max_score', '') ~ '^[0-9]+$'
          THEN (up.metadata->>'max_score')::bigint
        ELSE 0
      END
    )::bigint AS potential_gamerscore,
    COUNT(DISTINCT ROW(up.platform_id, up.platform_game_id)) AS total_games
  FROM public.user_progress up
  WHERE up.platform_id IN (10, 11, 12)
  GROUP BY up.user_id
),
xbox_achievement_count AS (
  SELECT
    ua.user_id,
    COUNT(*)::bigint AS achievement_count
  FROM public.user_achievements ua
  WHERE ua.platform_id IN (10, 11, 12)
  GROUP BY ua.user_id
)
SELECT
  xus.user_id,
  COALESCE(p.xbox_gamertag, p.display_name, p.username, 'Player') AS display_name,
  p.xbox_avatar_url AS avatar_url,
  COALESCE(xac.achievement_count, 0::bigint) AS achievement_count,
  xus.total_games,
  COALESCE(
    p.xbox_profile_gamerscore::bigint,
    xus.total_gamerscore,
    0::bigint
  ) AS gamerscore,
  COALESCE(xus.potential_gamerscore, 0::bigint) AS potential_gamerscore,
  NOW() AS updated_at
FROM xbox_user_stats xus
JOIN public.profiles p ON p.id = xus.user_id
LEFT JOIN xbox_achievement_count xac ON xac.user_id = xus.user_id
WHERE p.show_on_leaderboard = true
ORDER BY
  COALESCE(
    p.xbox_profile_gamerscore::bigint,
    xus.total_gamerscore,
    0::bigint
  ) DESC,
  COALESCE(xac.achievement_count, 0::bigint) DESC,
  xus.total_games DESC;

COMMENT ON VIEW public.xbox_leaderboard_cache IS
  'Xbox leaderboard using profile Gamerscore and per-title metadata maximums; avoids full achievements-catalog joins.';

GRANT SELECT ON public.xbox_leaderboard_cache
  TO anon, authenticated, service_role;

COMMIT;
