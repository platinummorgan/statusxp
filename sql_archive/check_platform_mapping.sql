-- Check platform mappings across all IDs
SELECT 
  platform_id,
  COUNT(*) as game_count,
  MIN(name) as sample_game
FROM games
GROUP BY platform_id
ORDER BY platform_id;
