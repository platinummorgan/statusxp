-- Check what base_status_xp values are actually stored in the database

SELECT 
  base_status_xp,
  COUNT(*) as count,
  rarity_multiplier,
  COUNT(*) FILTER (WHERE rarity_multiplier = 1.00) as common_count,
  COUNT(*) FILTER (WHERE rarity_multiplier = 1.25) as uncommon_count,
  COUNT(*) FILTER (WHERE rarity_multiplier = 1.75) as rare_count,
  COUNT(*) FILTER (WHERE rarity_multiplier = 2.25) as very_rare_count,
  COUNT(*) FILTER (WHERE rarity_multiplier = 3.00) as ultra_rare_count
FROM achievements
WHERE platform_id = 1
  AND include_in_score = true
GROUP BY base_status_xp, rarity_multiplier
ORDER BY base_status_xp;
