-- Check if DLC trophy groups are being captured
-- Look at games with multiple trophy groups

SELECT 
  gt.title,
  gt.psn_has_trophy_groups,
  COUNT(DISTINCT t.psn_trophy_group_id) as trophy_group_count,
  STRING_AGG(DISTINCT t.psn_trophy_group_id, ', ' ORDER BY t.psn_trophy_group_id) as groups,
  COUNT(t.id) as total_trophies
FROM game_titles gt
LEFT JOIN trophies t ON t.game_title_id = gt.id
WHERE gt.id IN (
  -- Get games that have multiple trophy groups
  SELECT game_title_id 
  FROM trophies 
  GROUP BY game_title_id 
  HAVING COUNT(DISTINCT psn_trophy_group_id) > 1
)
GROUP BY gt.id, gt.title, gt.psn_has_trophy_groups
ORDER BY trophy_group_count DESC, total_trophies DESC
LIMIT 20;
