-- Check if there are duplicate games in the games table causing JOIN duplicates
SELECT 
  g.name,
  g.platform_id,
  g.platform_game_id,
  COUNT(*) as count
FROM games g
WHERE g.name = 'STAR WARS Jedi: Fallen Order'
  AND g.platform_id = 1
GROUP BY g.name, g.platform_id, g.platform_game_id
ORDER BY count DESC;
