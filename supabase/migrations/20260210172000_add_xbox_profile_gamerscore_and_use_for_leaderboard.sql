-- Store authoritative Xbox profile gamerscore and prefer it in leaderboard totals.
-- This avoids undercount drift when per-title APIs miss edge titles/legacy entries.

BEGIN;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS xbox_profile_gamerscore integer;

COMMENT ON COLUMN public.profiles.xbox_profile_gamerscore IS
  'Authoritative Xbox profile gamerscore fetched from profile.xboxlive.com Gamerscore setting.';

CREATE OR REPLACE VIEW public.xbox_leaderboard_cache AS
WITH xbox_user_stats AS (
  SELECT
    up.user_id,
    SUM(up.current_score)::bigint AS total_gamerscore,
    COUNT(DISTINCT ROW(up.platform_id, up.platform_game_id)) AS total_games
  FROM public.user_progress up
  WHERE up.platform_id IN (10, 11, 12)
  GROUP BY up.user_id
),
xbox_potential AS (
  SELECT
    up.user_id,
    SUM(a.score_value)::bigint AS potential_gamerscore
  FROM public.user_progress up
  JOIN public.achievements a
    ON a.platform_id = up.platform_id
   AND a.platform_game_id = up.platform_game_id
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
  COALESCE(p.xbox_profile_gamerscore::bigint, COALESCE(xus.total_gamerscore, 0::bigint)) AS gamerscore,
  COALESCE(xp.potential_gamerscore, 0::bigint) AS potential_gamerscore,
  NOW() AS updated_at
FROM xbox_user_stats xus
JOIN public.profiles p
  ON p.id = xus.user_id
LEFT JOIN xbox_achievement_count xac
  ON xac.user_id = xus.user_id
LEFT JOIN xbox_potential xp
  ON xp.user_id = xus.user_id
WHERE p.show_on_leaderboard = true
ORDER BY
  COALESCE(p.xbox_profile_gamerscore::bigint, COALESCE(xus.total_gamerscore, 0::bigint)) DESC,
  COALESCE(xac.achievement_count, 0::bigint) DESC,
  xus.total_games DESC;

COMMENT ON VIEW public.xbox_leaderboard_cache IS
  'Xbox leaderboard (360/One/Series). Prefers profiles.xbox_profile_gamerscore when available; falls back to user_progress current_score sum.';

COMMIT;
