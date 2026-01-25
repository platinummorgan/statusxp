-- Check which platforms have missing rarity_global values
SELECT 
  platform_id,
  COUNT(*) as missing_rarity_count,
  ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM achievements), 2) as percent_of_total
FROM achievements
WHERE rarity_global IS NULL
  AND include_in_score = true
GROUP BY platform_id
ORDER BY missing_rarity_count DESC;

-- Also show total achievements per platform for context
SELECT 
  platform_id,
  COUNT(*) as total_achievements,
  COUNT(CASE WHEN rarity_global IS NULL THEN 1 END) as missing_rarity,
  ROUND(COUNT(CASE WHEN rarity_global IS NULL THEN 1 END) * 100.0 / COUNT(*), 2) as percent_missing
FROM achievements
WHERE include_in_score = true
GROUP BY platform_id
ORDER BY platform_id;
