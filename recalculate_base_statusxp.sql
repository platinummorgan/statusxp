-- Recalculate base_status_xp for all existing achievements
-- This updates any old data to match the current trigger logic

UPDATE achievements
SET base_status_xp = CASE
    WHEN include_in_score = false THEN 0
    WHEN rarity_global IS NULL THEN 10
    WHEN rarity_global > 25 THEN 10
    WHEN rarity_global > 10 THEN 13
    WHEN rarity_global > 5 THEN 18
    WHEN rarity_global > 1 THEN 23
    ELSE 30
END
WHERE rarity_global IS NOT NULL;

-- Verify the update
SELECT 
  COUNT(*) as total_updated,
  COUNT(CASE WHEN base_status_xp = 10 THEN 1 END) as common_10xp,
  COUNT(CASE WHEN base_status_xp = 13 THEN 1 END) as uncommon_13xp,
  COUNT(CASE WHEN base_status_xp = 18 THEN 1 END) as rare_18xp,
  COUNT(CASE WHEN base_status_xp = 23 THEN 1 END) as very_rare_23xp,
  COUNT(CASE WHEN base_status_xp = 30 THEN 1 END) as ultra_rare_30xp,
  COUNT(CASE WHEN base_status_xp = 0 THEN 1 END) as excluded_0xp
FROM achievements
WHERE rarity_global IS NOT NULL;
