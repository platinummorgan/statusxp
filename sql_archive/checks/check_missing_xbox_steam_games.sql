-- Check if your Xbox/Steam games exist in user_progress
SELECT 
  p.display_name,
  plat.code as platform,
  up.platform_id,
  COUNT(DISTINCT up.platform_game_id) as game_count,
  SUM(up.achievements_earned) as total_achievements
FROM user_progress up
INNER JOIN profiles p ON p.id = up.user_id
INNER JOIN platforms plat ON plat.id = up.platform_id
WHERE p.display_name = 'Dex-Morgan'
  AND up.platform_id IN (5, 10, 11, 12)  -- Steam, Xbox360, XboxOne, XboxSeriesX
GROUP BY p.display_name, plat.code, up.platform_id
ORDER BY up.platform_id;

-- Check if games exist in games table
SELECT 
  plat.code as platform,
  g.platform_id,
  COUNT(DISTINCT g.platform_game_id) as game_count
FROM games g
INNER JOIN platforms plat ON plat.id = g.platform_id
WHERE g.platform_id IN (5, 10, 11, 12)
GROUP BY plat.code, g.platform_id
ORDER BY g.platform_id;

-- Check what's in the user_games view for your account
SELECT COUNT(*) as psn_games
FROM user_games
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Try to see if we can query user_progress directly
SELECT 
  g.name,
  plat.code as platform,
  up.achievements_earned,
  up.total_achievements,
  up.completion_percent
FROM user_progress up
INNER JOIN games g ON g.platform_id = up.platform_id AND g.platform_game_id = up.platform_game_id
INNER JOIN platforms plat ON plat.id = up.platform_id
WHERE up.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND up.platform_id IN (10, 11, 12)  -- Xbox
LIMIT 10;
