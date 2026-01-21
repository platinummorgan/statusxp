-- Check games with at least 1 achievement earned
SELECT 
  'PSN' as platform,
  COUNT(DISTINCT g.platform_game_id) as games_with_progress
FROM games g
INNER JOIN user_achievements ua ON g.platform_id = ua.platform_id AND g.platform_game_id = ua.platform_game_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND g.platform_id IN (1, 2, 5, 9)

UNION ALL

SELECT 
  'Xbox' as platform,
  COUNT(DISTINCT g.platform_game_id) as games_with_progress
FROM games g
INNER JOIN user_achievements ua ON g.platform_id = ua.platform_id AND g.platform_game_id = ua.platform_game_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND g.platform_id IN (10, 11, 12)

UNION ALL

SELECT 
  'Steam' as platform,
  COUNT(DISTINCT g.platform_game_id) as games_with_progress
FROM games g
INNER JOIN user_achievements ua ON g.platform_id = ua.platform_id AND g.platform_game_id = ua.platform_game_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND g.platform_id = 4;

-- Also check if there are missing platform IDs
SELECT 
  g.platform_id,
  COUNT(DISTINCT g.platform_game_id) as games_with_achievements
FROM games g
INNER JOIN user_achievements ua ON g.platform_id = ua.platform_id AND g.platform_game_id = ua.platform_game_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
GROUP BY g.platform_id
ORDER BY g.platform_id;
