-- Temporary query to check DLC trophy groups
-- Run this in Supabase SQL Editor

-- 1. Overall stats
SELECT 
  'Total Games' as metric,
  COUNT(*)::text as value
FROM game_titles
UNION ALL
SELECT 
  'Games with DLC Flag',
  COUNT(*)::text
FROM game_titles
WHERE psn_has_trophy_groups = true
UNION ALL
SELECT 
  'Total Trophies',
  COUNT(*)::text
FROM trophies
UNION ALL
SELECT
  'DLC Trophies (non-default group)',
  COUNT(*)::text
FROM trophies
WHERE psn_trophy_group_id != 'default';

-- 2. Games with multiple trophy groups
SELECT 
  gt.title,
  gt.psn_has_trophy_groups as has_dlc_flag,
  COUNT(DISTINCT t.psn_trophy_group_id) as group_count,
  STRING_AGG(DISTINCT t.psn_trophy_group_id, ', ' ORDER BY t.psn_trophy_group_id) as groups,
  COUNT(t.id) as total_trophies
FROM game_titles gt
LEFT JOIN trophies t ON t.game_title_id = gt.id
GROUP BY gt.id, gt.title, gt.psn_has_trophy_groups
HAVING COUNT(DISTINCT t.psn_trophy_group_id) > 1
ORDER BY group_count DESC, total_trophies DESC
LIMIT 10;

-- 3. Sample DLC trophies
SELECT 
  gt.title as game,
  t.name as trophy_name,
  t.psn_trophy_group_id as group_id,
  t.psn_trophy_type as type
FROM trophies t
JOIN game_titles gt ON gt.id = t.game_title_id
WHERE t.psn_trophy_group_id != 'default'
ORDER BY gt.title, t.psn_trophy_group_id, t.sort_order
LIMIT 20;
