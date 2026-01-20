-- Check actual platform IDs in use
SELECT DISTINCT 
  p.id,
  p.code,
  p.name,
  COUNT(DISTINCT ua.platform_game_id) as game_count
FROM platforms p
LEFT JOIN user_achievements ua ON ua.platform_id = p.id
WHERE ua.user_id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d'
GROUP BY p.id, p.code, p.name
ORDER BY p.id;
