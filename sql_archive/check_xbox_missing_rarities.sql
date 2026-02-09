-- Find Xbox games with NULL rarities
SELECT 
  g.platform_game_id as title_id,
  g.name as game_name,
  COUNT(*) as total_achievements,
  COUNT(CASE WHEN a.rarity_global IS NULL THEN 1 END) as null_rarity_count,
  ROUND(COUNT(CASE WHEN a.rarity_global IS NULL THEN 1 END) * 100.0 / COUNT(*), 2) as percent_missing
FROM games g
JOIN achievements a ON 
  a.platform_id = g.platform_id 
  AND a.platform_game_id = g.platform_game_id
WHERE g.platform_id IN (10, 11, 12) -- All Xbox platforms
  AND a.include_in_score = true
GROUP BY g.platform_game_id, g.name
HAVING COUNT(CASE WHEN a.rarity_global IS NULL THEN 1 END) > 0
ORDER BY null_rarity_count DESC
LIMIT 20;
