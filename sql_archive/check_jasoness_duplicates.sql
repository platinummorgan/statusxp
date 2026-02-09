-- Check for duplicate platform_game_ids for jgmartinez24@gmail.com
-- UUID: 68dd426c-3ce9-45e0-a9e6-70a9d3127eb8

SELECT 
  g.platform_game_id,
  g.name,
  array_agg(g.platform_id ORDER BY g.platform_id) as platform_ids,
  array_agg(CASE g.platform_id
    WHEN 1 THEN 'PS5'
    WHEN 2 THEN 'PS4'
    WHEN 5 THEN 'PS3'
    WHEN 9 THEN 'PSVITA'
  END ORDER BY g.platform_id) as platform_names,
  COUNT(DISTINCT g.platform_id) as platform_count
FROM games g
WHERE EXISTS (
  SELECT 1 FROM user_achievements ua
  WHERE ua.user_id = '68dd426c-3ce9-45e0-a9e6-70a9d3127eb8'
    AND ua.platform_id = g.platform_id
    AND ua.platform_game_id = g.platform_game_id
)
GROUP BY g.platform_game_id, g.name
HAVING COUNT(DISTINCT g.platform_id) > 1
ORDER BY name;
