-- Find Happy Wars titleId
SELECT 
  platform_id,
  platform_game_id,
  name,
  (SELECT COUNT(*) FROM achievements a 
   WHERE a.platform_game_id = g.platform_game_id 
   AND a.platform_id = g.platform_id) as total_achievements,
  (SELECT COUNT(*) FROM achievements a 
   WHERE a.platform_game_id = g.platform_game_id 
   AND a.platform_id = g.platform_id 
   AND a.rarity_global IS NULL) as null_rarity_count
FROM games g
WHERE LOWER(name) LIKE '%happy wars%';
