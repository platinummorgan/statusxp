-- Check what platform values exist in user_games
SELECT DISTINCT platform 
FROM user_games
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Check PSN game count with different platform names
SELECT 
  COUNT(*) as game_count,
  platform
FROM user_games
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
GROUP BY platform;
