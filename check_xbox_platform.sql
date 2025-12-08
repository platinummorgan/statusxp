-- Check what platforms exist and how Xbox is stored
SELECT * FROM platforms ORDER BY name;

-- Check if we have any Xbox games at all
SELECT 
  COUNT(*) as xbox_game_count
FROM user_games ug
JOIN platforms p ON ug.platform_id = p.id
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND (p.name LIKE '%Xbox%' OR p.code LIKE '%Xbox%' OR p.name = 'xbox' OR p.code = 'xbox');

-- Check all platforms for this user
SELECT 
  p.name,
  p.code,
  COUNT(*) as game_count
FROM user_games ug
JOIN platforms p ON ug.platform_id = p.id
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
GROUP BY p.name, p.code
ORDER BY game_count DESC;
