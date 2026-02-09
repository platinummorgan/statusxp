-- Check where #IDARB achievements are actually stored
SELECT 
  g.platform_id,
  g.platform_game_id,
  g.name,
  COUNT(a.platform_achievement_id) as achievement_count
FROM games g
LEFT JOIN achievements a ON 
  a.platform_id = g.platform_id 
  AND a.platform_game_id = g.platform_game_id
WHERE LOWER(g.name) = '#idarb'
  AND g.platform_id IN (10, 11, 12)
GROUP BY g.platform_id, g.platform_game_id, g.name
ORDER BY g.platform_id;

-- Also check the first few Xbox games from browse to see the pattern
SELECT 
  g.platform_id,
  g.platform_game_id,
  g.name,
  COUNT(a.platform_achievement_id) as achievement_count
FROM games g
LEFT JOIN achievements a ON 
  a.platform_id = g.platform_id 
  AND a.platform_game_id = g.platform_game_id
WHERE g.name IN ('101 Ways To Die', '1979 Revolution: Black Friday', '2 Synchro Hedgehogs')
  AND g.platform_id IN (10, 11, 12)
GROUP BY g.platform_id, g.platform_game_id, g.name
ORDER BY g.name, g.platform_id;
