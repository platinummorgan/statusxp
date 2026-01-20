-- Test Xbox games in browse function
SELECT 
  name,
  primary_platform_id,
  primary_game_id,
  platforms,
  platform_ids,
  total_achievements
FROM get_grouped_games_fast(NULL, 'xbox', 10, 0)
LIMIT 10;

-- Check if Xbox games exist in games table
SELECT 
  platform_id,
  COUNT(*) as game_count
FROM games
WHERE platform_id IN (10, 11, 12)  -- Xbox 360, Xbox One, Xbox Series X
GROUP BY platform_id
ORDER BY platform_id;

-- Check if Xbox achievements exist
SELECT 
  g.platform_id,
  g.name,
  COUNT(a.platform_achievement_id) as achievement_count
FROM games g
LEFT JOIN achievements a ON a.platform_id = g.platform_id 
  AND a.platform_game_id = g.platform_game_id
WHERE g.platform_id IN (10, 11, 12)
GROUP BY g.platform_id, g.name
ORDER BY achievement_count DESC
LIMIT 10;
