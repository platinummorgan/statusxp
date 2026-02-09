-- Migration: Fix Xbox leaderboard gamerscore calculation
-- Issue #8: Xbox Leaderboards calculating impossibly high Gamerscores
-- 
-- Problem: The view was joining user_achievements with user_progress, which resulted in
-- multiplying each game's total gamerscore by the number of achievements earned in that game.
-- 
-- Example bug: User has 10 achievements in a 1000G game → counted as 10,000G instead of 1,000G
-- 
-- Solution: Use DISTINCT on the user_progress join to count each game's gamerscore only once,
-- OR better yet, use a subquery to sum user_progress separately from counting achievements.

CREATE OR REPLACE VIEW "public"."xbox_leaderboard_cache" AS
WITH xbox_user_stats AS (
  -- Count achievements per user
  SELECT 
    ua.user_id,
    COUNT(*) AS achievement_count,
    COUNT(DISTINCT a.platform_game_id) AS total_games
  FROM user_achievements ua
  JOIN achievements a ON 
    a.platform_id = ua.platform_id 
    AND a.platform_game_id = ua.platform_game_id 
    AND a.platform_achievement_id = ua.platform_achievement_id
  WHERE ua.platform_id IN (10, 11, 12) -- Xbox 360, One, Series X/S
  GROUP BY ua.user_id
),
xbox_gamerscore AS (
  -- Sum gamerscore from user_progress (each record = one game's total score)
  SELECT 
    up.user_id,
    COALESCE(SUM(up.current_score), 0) AS gamerscore
  FROM user_progress up
  WHERE up.platform_id IN (10, 11, 12) -- Xbox platforms
  GROUP BY up.user_id
)
SELECT 
  xus.user_id,
  COALESCE(p.xbox_gamertag, p.display_name, p.username, 'Player') AS display_name,
  p.xbox_avatar_url AS avatar_url,
  xus.achievement_count,
  xus.total_games,
  COALESCE(xg.gamerscore, 0) AS gamerscore,
  NOW() AS updated_at
FROM xbox_user_stats xus
JOIN profiles p ON p.id = xus.user_id
LEFT JOIN xbox_gamerscore xg ON xg.user_id = xus.user_id
WHERE p.show_on_leaderboard = true
  AND xus.achievement_count > 0
ORDER BY 
  COALESCE(xg.gamerscore, 0) DESC,
  xus.achievement_count DESC,
  xus.total_games DESC;
COMMENT ON VIEW "public"."xbox_leaderboard_cache" IS 'Xbox leaderboard showing all Xbox platforms (360, One, Series X/S). Uses xbox_avatar_url for platform-specific avatars. Uses V2 schema with user_progress for gamerscore. Fixed: Gamerscore now correctly sums per-game scores instead of multiplying by achievement count.';
