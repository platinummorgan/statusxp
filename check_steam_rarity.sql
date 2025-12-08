-- Check Steam achievement rarity data
SELECT 
  COUNT(*) as total_steam_achievements,
  COUNT(*) FILTER (WHERE rarity_global IS NOT NULL) as has_rarity_global,
  COUNT(*) FILTER (WHERE rarity_global > 0) as has_positive_rarity,
  ROUND(AVG(rarity_global), 2) as avg_rarity,
  MIN(rarity_global) as min_rarity,
  MAX(rarity_global) as max_rarity
FROM achievements
WHERE platform = 'steam';

-- Sample of Steam achievements with rarity
SELECT 
  gt.name as game,
  a.name as achievement,
  a.rarity_global,
  a.rarity_band,
  a.rarity_multiplier
FROM achievements a
JOIN game_titles gt ON a.game_title_id = gt.id
WHERE a.platform = 'steam'
  AND a.rarity_global IS NOT NULL
ORDER BY a.rarity_global ASC
LIMIT 10;
