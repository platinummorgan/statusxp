-- Verify cleanup for specific user
-- Replace USER_ID with your actual user_id

SELECT 
  COUNT(*) as total_games,
  COUNT(DISTINCT platform_game_id) as unique_games,
  COUNT(*) - COUNT(DISTINCT platform_game_id) as duplicates
FROM user_progress
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';  -- Replace with your user_id

-- Check if Star Wars Jedi still has duplicates
SELECT 
  up.platform_id,
  up.platform_game_id,
  g.name as game_name
FROM user_progress up
JOIN games g ON up.platform_id = g.platform_id AND up.platform_game_id = g.platform_game_id
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'  -- Replace with your user_id
  AND g.name ILIKE '%star wars%jedi%'
ORDER BY up.platform_id;
