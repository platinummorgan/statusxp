-- Is there actually a Steam platform (platform_id=4)?
SELECT 
  COUNT(*) as steam_games
FROM user_progress
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND platform_id = 4;
