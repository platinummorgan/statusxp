-- Check what your platform 5 games actually are
SELECT 
  g.name,
  g.platform_game_id
FROM user_progress up
INNER JOIN games g ON g.platform_id = up.platform_id AND g.platform_game_id = up.platform_game_id
WHERE up.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND up.platform_id = 5
ORDER BY g.name
LIMIT 20;
