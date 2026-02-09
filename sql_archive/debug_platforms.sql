-- Debug why platforms are showing as unknown
SELECT 
  p.id,
  p.code,
  p.name,
  COUNT(g.platform_id) as game_count
FROM platforms p
LEFT JOIN games g ON g.platform_id = p.id
GROUP BY p.id, p.code, p.name
ORDER BY p.id;

-- Check a sample game with its platform
SELECT 
  g.name as game_name,
  g.platform_id,
  p.code as platform_code,
  p.name as platform_name
FROM games g
JOIN platforms p ON p.id = g.platform_id
LIMIT 10;
