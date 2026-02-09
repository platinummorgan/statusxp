-- Check what user_games actually has for Steam games
SELECT 
  game_title,
  platform_id,
  last_played_at,
  last_trophy_earned_at
FROM user_games
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND platform_id = 4
LIMIT 10;
