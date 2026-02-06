-- Run this BEFORE syncing to establish baseline
-- Run this AFTER syncing to verify no duplicates were created

SELECT 
  'PSN Achievement Count' as metric,
  COUNT(*) as value
FROM achievements 
WHERE platform_id IN (1, 2)

UNION ALL

SELECT 
  'Unique PSN Games' as metric,
  COUNT(DISTINCT platform_game_id) as value
FROM achievements 
WHERE platform_id IN (1, 2)

UNION ALL

SELECT 
  'Achievements with DLC names' as metric,
  COUNT(*) as value
FROM achievements 
WHERE platform_id IN (1, 2)
  AND metadata->>'dlc_name' IS NOT NULL

UNION ALL

SELECT 
  'Base Game achievements' as metric,
  COUNT(*) as value
FROM achievements 
WHERE platform_id IN (1, 2)
  AND (metadata->>'is_dlc' = 'false' OR metadata->>'dlc_name' IS NULL)

UNION ALL

SELECT 
  'DLC achievements' as metric,
  COUNT(*) as value
FROM achievements 
WHERE platform_id IN (1, 2)
  AND metadata->>'is_dlc' = 'true'
  AND metadata->>'dlc_name' IS NOT NULL;

-- Check for any duplicate achievements (should be ZERO both before and after)
SELECT 
  'DUPLICATE CHECK' as metric,
  COUNT(*) as duplicate_count
FROM (
  SELECT platform_id, platform_game_id, platform_achievement_id, COUNT(*) as cnt
  FROM achievements
  WHERE platform_id IN (1, 2)
  GROUP BY platform_id, platform_game_id, platform_achievement_id
  HAVING COUNT(*) > 1
) dupes;
