-- Check actual platform IDs in use
SELECT DISTINCT 
  up.platform_id,
  COUNT(*) as game_count,
  STRING_AGG(DISTINCT g.name, ', ' ORDER BY g.name) as sample_games
FROM user_progress up
JOIN games g ON g.platform_id = up.platform_id 
  AND g.platform_game_id = up.platform_game_id
GROUP BY up.platform_id
ORDER BY up.platform_id;

-- Check if there's a platforms reference table
SELECT id, name, code 
FROM platforms 
ORDER BY id;
