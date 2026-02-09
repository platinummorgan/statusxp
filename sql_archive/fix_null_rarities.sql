-- ============================================================================
-- Fix NULL rarities: Assign default value of 50% (median rarity)
-- ============================================================================
-- For achievements without rarity data (primarily Xbox via OpenXBL),
-- assign a default rarity of 50% which equals 5 points in the 1-10 scale.
-- This is a fair middle-ground assumption.

-- Check current NULL rarities
SELECT 
  platform_id,
  COUNT(*) as null_rarity_count,
  COUNT(*) * 100.0 / (SELECT COUNT(*) FROM achievements WHERE include_in_score = true) as percent_of_total
FROM achievements
WHERE rarity_global IS NULL
  AND include_in_score = true
GROUP BY platform_id;

-- Option 1: Set NULL rarities to 50% (median assumption)
UPDATE achievements
SET 
  rarity_global = 50.0,
  base_status_xp = 5  -- 50% rarity = 5 points in 1-10 scale
WHERE rarity_global IS NULL
  AND include_in_score = true;

-- Option 2: Set NULL rarities to 25% (uncommon - slightly optimistic)
-- UPDATE achievements
-- SET 
--   rarity_global = 25.0,
--   base_status_xp = 7  -- 25% rarity = ~7 points in 1-10 scale
-- WHERE rarity_global IS NULL
--   AND include_in_score = true;

-- Verify the update
SELECT 
  platform_id,
  COUNT(*) as total_achievements,
  COUNT(CASE WHEN rarity_global IS NULL THEN 1 END) as still_null,
  ROUND(AVG(base_status_xp), 2) as avg_points
FROM achievements
WHERE include_in_score = true
GROUP BY platform_id
ORDER BY platform_id;
