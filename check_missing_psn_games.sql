-- Check if you have PS Vita games
SELECT 
  COUNT(*) as vita_games,
  COUNT(DISTINCT platform_game_id) as unique_vita_games
FROM user_progress
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND platform_id = 9;

-- Also check where platform 5 games came from (PSN or Steam?)
SELECT 
  platform_game_id,
  name
FROM games
WHERE platform_id = 5
  AND (platform_game_id, platform_id) IN (
    SELECT platform_game_id, platform_id 
    FROM user_progress 
    WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a' 
      AND platform_id = 5
  )
LIMIT 10;
