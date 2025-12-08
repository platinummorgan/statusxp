-- Check PSN rarity data after sync
SELECT 
  platform,
  COUNT(*) as total_achievements,
  COUNT(rarity_global) as with_rarity,
  COUNT(CASE WHEN rarity_global > 0 THEN 1 END) as with_nonzero_rarity,
  ROUND(AVG(CASE WHEN rarity_global > 0 THEN rarity_global END), 2) as avg_rarity_nonzero,
  MIN(CASE WHEN rarity_global > 0 THEN rarity_global END) as rarest_nonzero,
  MAX(rarity_global) as most_common
FROM achievements
GROUP BY platform;

-- Check rarity band distribution
SELECT 
  platform,
  rarity_band,
  COUNT(*) as count,
  ROUND(AVG(rarity_global), 2) as avg_rarity
FROM achievements
WHERE rarity_global IS NOT NULL
GROUP BY platform, rarity_band
ORDER BY platform, rarity_band;

-- Sample PSN achievements with rarity
SELECT 
  name,
  platform,
  rarity_global,
  rarity_band,
  base_status_xp,
  is_platinum,
  psn_trophy_type
FROM achievements
WHERE platform = 'psn' AND rarity_global IS NOT NULL
ORDER BY rarity_global ASC
LIMIT 20;

-- Check if trigger is working on new inserts
SELECT 
  COUNT(*) as total,
  COUNT(rarity_band) as has_rarity_band,
  COUNT(base_status_xp) as has_base_xp
FROM achievements
WHERE rarity_global IS NOT NULL;
