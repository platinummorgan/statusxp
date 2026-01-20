-- Calculate StatusXP the CORRECT way: per-game, then sum games
-- Not global sum of all achievements (which gives 649k)

WITH user_game_statusxp AS (
  SELECT 
    ua.user_id,
    ua.platform_id,
    ua.platform_game_id,
    COUNT(*) as achievements_earned,
    SUM(a.base_status_xp) as game_statusxp
  FROM user_achievements ua
  JOIN achievements a ON 
    a.platform_id = ua.platform_id
    AND a.platform_game_id = ua.platform_game_id
    AND a.platform_achievement_id = ua.platform_achievement_id
  WHERE ua.user_id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d'
    AND a.include_in_score = true
  GROUP BY ua.user_id, ua.platform_id, ua.platform_game_id
)

SELECT 
  COUNT(*) as total_games,
  SUM(achievements_earned) as total_achievements,
  SUM(game_statusxp) as total_statusxp,
  ROUND(AVG(game_statusxp), 2) as avg_statusxp_per_game,
  MIN(game_statusxp) as min_game_statusxp,
  MAX(game_statusxp) as max_game_statusxp
FROM user_game_statusxp;

-- Also show top 10 games by StatusXP
WITH user_game_statusxp AS (
  SELECT 
    ua.user_id,
    ua.platform_id,
    ua.platform_game_id,
    COUNT(*) as achievements_earned,
    SUM(a.base_status_xp) as game_statusxp
  FROM user_achievements ua
  JOIN achievements a ON 
    a.platform_id = ua.platform_id
    AND a.platform_game_id = ua.platform_game_id
    AND a.platform_achievement_id = ua.platform_achievement_id
  WHERE ua.user_id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d'
    AND a.include_in_score = true
  GROUP BY ua.user_id, ua.platform_id, ua.platform_game_id
)
SELECT 
  g.name,
  g.platform_id,
  ugs.achievements_earned,
  ugs.game_statusxp
FROM user_game_statusxp ugs
JOIN games g ON g.platform_id = ugs.platform_id 
  AND g.platform_game_id = ugs.platform_game_id
ORDER BY ugs.game_statusxp DESC
LIMIT 10;
