-- Check Star Wars Jedi: Fallen Order entries in database
SELECT 
  g.platform_id,
  g.platform_game_id,
  g.name,
  p.name as platform_name,
  COUNT(DISTINCT up.user_id) as users_with_game,
  COUNT(DISTINCT ua.user_id) as users_with_achievements
FROM games g
LEFT JOIN platforms p ON g.platform_id = p.id
LEFT JOIN user_progress up ON g.platform_id = up.platform_id AND g.platform_game_id = up.platform_game_id
LEFT JOIN user_achievements ua ON g.platform_id = ua.platform_id AND g.platform_game_id = ua.platform_game_id
WHERE g.name ILIKE '%jedi%fallen%order%'
  OR g.name ILIKE '%star wars jedi%'
GROUP BY g.platform_id, g.platform_game_id, g.name, p.name
ORDER BY g.platform_id;

-- Check YOUR specific entries for Jedi
SELECT 
  up.platform_id,
  up.platform_game_id,
  g.name,
  up.achievements_earned,
  up.total_achievements,
  up.completion_percentage,
  COUNT(ua.platform_achievement_id) as actual_achievement_count
FROM user_progress up
JOIN games g ON up.platform_id = g.platform_id AND up.platform_game_id = g.platform_game_id
LEFT JOIN user_achievements ua ON up.user_id = ua.user_id 
  AND up.platform_id = ua.platform_id 
  AND up.platform_game_id = ua.platform_game_id
WHERE up.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND (g.name ILIKE '%jedi%fallen%order%' OR g.name ILIKE '%star wars jedi%')
GROUP BY up.platform_id, up.platform_game_id, g.name, up.achievements_earned, up.total_achievements, up.completion_percentage
ORDER BY up.platform_id;
