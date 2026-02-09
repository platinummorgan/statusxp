SELECT 
  COUNT(*) as total_platinums
FROM user_achievements ua
JOIN achievements a 
  ON a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id 
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = '68dd426c-3ce9-45e0-a9e6-70a9d3127eb8'
  AND a.is_platinum = true;
