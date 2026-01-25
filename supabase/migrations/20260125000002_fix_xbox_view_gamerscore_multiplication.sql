-- Fix: View should sum gamerscore per GAME, not per achievement
-- Current: joins through achievements table, multiplies gamerscore
-- Fix: Use subquery to aggregate by game first

BEGIN;

CREATE OR REPLACE VIEW "public"."xbox_leaderboard_cache" AS
WITH game_gamerscore AS (
  -- First, get gamerscore per game for each user
  SELECT 
    up.user_id,
    COALESCE(
      (up.metadata->>'current_gamerscore')::integer,
      ROUND((up.metadata->>'max_gamerscore')::numeric * up.completion_percentage / 100)::integer,
      0
    ) as game_gamerscore
  FROM user_progress up
  WHERE up.platform_id IN (10, 11, 12)
)
SELECT 
  ua.user_id,
  COALESCE(p.xbox_gamertag, p.display_name, p.username, 'Player') AS display_name,
  p.xbox_avatar_url AS avatar_url,
  COUNT(*) AS achievement_count,
  COUNT(DISTINCT a.platform_game_id) AS total_games,
  COALESCE((SELECT SUM(gg.game_gamerscore) FROM game_gamerscore gg WHERE gg.user_id = ua.user_id), 0) AS gamerscore,
  now() AS updated_at
FROM user_achievements ua
JOIN achievements a ON 
  a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
JOIN profiles p ON p.id = ua.user_id
WHERE ua.platform_id IN (10, 11, 12)
  AND p.show_on_leaderboard = true
GROUP BY ua.user_id, p.xbox_gamertag, p.display_name, p.username, p.xbox_avatar_url
HAVING COUNT(*) > 0
ORDER BY COALESCE((SELECT SUM(gg.game_gamerscore) FROM game_gamerscore gg WHERE gg.user_id = ua.user_id), 0) DESC, 
         COUNT(*) DESC, 
         COUNT(DISTINCT a.platform_game_id) DESC;

COMMENT ON VIEW "public"."xbox_leaderboard_cache" IS 'Xbox leaderboard showing all Xbox platforms (360, One, Series X/S). Gamerscore calculated per game from metadata to avoid achievement-level multiplication.';

COMMIT;
