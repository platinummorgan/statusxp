-- Check a few specific games to see if their storage URLs work
-- Copy one of these URLs and paste in browser to test

SELECT 
  platform_id,
  platform_game_id,
  name,
  cover_url
FROM games
WHERE platform_game_id IN ('NPWR41319_00', 'NPWR24695_00', 'NPWR21904_00')
ORDER BY platform_id, platform_game_id;
