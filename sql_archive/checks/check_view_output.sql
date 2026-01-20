-- Check what psn_leaderboard_cache view is returning for Dex-Morgan

SELECT * FROM psn_leaderboard_cache 
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Also check: How many UNIQUE PSN games do you have?
SELECT COUNT(DISTINCT platform_game_id) as unique_psn_games
FROM user_achievements
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND platform_id = 1;

-- And check Steam games
SELECT COUNT(DISTINCT platform_game_id) as unique_steam_games
FROM user_achievements
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND platform_id = 5;

-- Check total achievements by platform
SELECT 
  platform_id,
  COUNT(*) as total_achievements,
  COUNT(DISTINCT platform_game_id) as unique_games
FROM user_achievements
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
GROUP BY platform_id
ORDER BY platform_id;
