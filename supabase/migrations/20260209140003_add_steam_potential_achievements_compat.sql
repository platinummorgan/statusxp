-- Seasonal Steam leaderboard functions require potential_achievements before
-- the later optimized Steam cache migration is applied.

DO $migration$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'steam_leaderboard_cache'
      AND column_name = 'potential_achievements'
  ) THEN
    DROP VIEW IF EXISTS public.steam_leaderboard_cache CASCADE;

    EXECUTE $view$
CREATE VIEW public.steam_leaderboard_cache AS
WITH earned AS (
  SELECT
    ua.user_id,
    COUNT(*)::bigint AS achievement_count,
    COUNT(DISTINCT ua.platform_game_id)::bigint AS total_games
  FROM public.user_achievements ua
  WHERE ua.platform_id = 4
  GROUP BY ua.user_id
),
potential AS (
  SELECT
    up.user_id,
    COALESCE(SUM(up.total_achievements), 0)::bigint AS potential_achievements
  FROM public.user_progress up
  WHERE up.platform_id = 4
  GROUP BY up.user_id
)
SELECT
  earned.user_id,
  COALESCE(p.steam_display_name, p.display_name, p.username, 'Player') AS display_name,
  p.steam_avatar_url AS avatar_url,
  earned.achievement_count,
  COALESCE(potential.potential_achievements, 0)::bigint AS potential_achievements,
  earned.total_games,
  now() AS updated_at
FROM earned
JOIN public.profiles p ON p.id = earned.user_id
LEFT JOIN potential ON potential.user_id = earned.user_id
WHERE p.show_on_leaderboard = true
  AND earned.achievement_count > 0
$view$;
  END IF;
END
$migration$;

GRANT SELECT ON public.steam_leaderboard_cache TO authenticated, anon;
