-- Check if ANY trophy has rarity data (from any source)
SELECT 
  COUNT(*) as total_trophies,
  COUNT(rarity_global) as has_rarity_global,
  COUNT(psn_earn_rate) as has_psn_earn_rate,
  MIN(rarity_global) as min_rarity,
  MAX(rarity_global) as max_rarity
FROM trophies;

-- Show some trophies with rarity if any exist
SELECT 
  t.id,
  t.name,
  t.tier,
  t.rarity_global,
  t.psn_earn_rate,
  gt.name as game_name
FROM trophies t
JOIN game_titles gt ON t.game_title_id = gt.id
WHERE t.rarity_global IS NOT NULL OR t.psn_earn_rate IS NOT NULL
LIMIT 10;
