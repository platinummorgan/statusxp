-- Deep dive into Xbox rarity values
SELECT 
  name,
  rarity_global,
  rarity_band,
  base_status_xp,
  created_at
FROM achievements
WHERE platform = 'xbox'
ORDER BY id DESC
LIMIT 20;

-- Check if ALL Xbox achievements are exactly 0.00
SELECT 
  COUNT(*) as total,
  COUNT(CASE WHEN rarity_global = 0 THEN 1 END) as exactly_zero,
  COUNT(CASE WHEN rarity_global IS NULL THEN 1 END) as null_values,
  COUNT(CASE WHEN rarity_global > 0 THEN 1 END) as has_value
FROM achievements
WHERE platform = 'xbox';

-- Sample of any Xbox achievements that DO have rarity > 0
SELECT 
  name,
  rarity_global,
  rarity_band
FROM achievements  
WHERE platform = 'xbox' AND rarity_global > 0
LIMIT 10;
