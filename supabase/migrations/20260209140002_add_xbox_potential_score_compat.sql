-- Seasonal leaderboard functions introduced immediately after this migration
-- require potential_gamerscore, but the earlier Xbox cache view omitted it.
-- A later migration replaces this view with authoritative profile scoring.

DROP VIEW IF EXISTS public.xbox_leaderboard_cache CASCADE;

CREATE VIEW public.xbox_leaderboard_cache AS
WITH xbox_user_stats AS (
  SELECT
    ua.user_id,
    COUNT(*)::bigint AS achievement_count,
    COUNT(DISTINCT a.platform_game_id)::bigint AS total_games,
    COALESCE(SUM(LEAST(a.score_value, 1000)), 0)::bigint AS gamerscore
  FROM public.user_achievements ua
  JOIN public.achievements a
    ON a.platform_id = ua.platform_id
   AND a.platform_game_id = ua.platform_game_id
   AND a.platform_achievement_id = ua.platform_achievement_id
  WHERE ua.platform_id IN (10, 11, 12)
  GROUP BY ua.user_id
),
xbox_potential AS (
  SELECT
    up.user_id,
    COALESCE(SUM(a.score_value), 0)::bigint AS potential_gamerscore
  FROM public.user_progress up
  JOIN public.achievements a
    ON a.platform_id = up.platform_id
   AND a.platform_game_id = up.platform_game_id
  WHERE up.platform_id IN (10, 11, 12)
  GROUP BY up.user_id
)
SELECT
  xus.user_id,
  COALESCE(p.xbox_gamertag, p.display_name, p.username, 'Player') AS display_name,
  p.xbox_avatar_url AS avatar_url,
  xus.achievement_count,
  xus.total_games,
  xus.gamerscore,
  COALESCE(xp.potential_gamerscore, 0)::bigint AS potential_gamerscore,
  now() AS updated_at
FROM xbox_user_stats xus
JOIN public.profiles p ON p.id = xus.user_id
LEFT JOIN xbox_potential xp ON xp.user_id = xus.user_id
WHERE p.show_on_leaderboard = true
  AND xus.achievement_count > 0;

GRANT SELECT ON public.xbox_leaderboard_cache TO authenticated, anon;
