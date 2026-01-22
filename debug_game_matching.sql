-- Debug: Check if the game name matching is working
SELECT 
  ug.game_title,
  g2.name as games_table_name,
  up.platform_game_id,
  COUNT(ua.platform_achievement_id) as achievement_count,
  MAX(ua.earned_at) as max_earned
FROM user_games ug
JOIN user_progress up ON up.user_id = ug.user_id 
  AND up.platform_id = ug.platform_id
JOIN games g2 ON g2.platform_id = up.platform_id
JOIN user_achievements ua ON ua.user_id = up.user_id
  AND ua.platform_id = up.platform_id
  AND ua.platform_game_id = up.platform_game_id
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND ug.platform_id = 4
  AND LOWER(g2.name) = LOWER(ug.game_title)
GROUP BY ug.game_title, g2.name, up.platform_game_id
LIMIT 5;
