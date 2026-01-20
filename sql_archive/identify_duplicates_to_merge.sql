-- Cleanup duplicate games in game_titles table
-- This will merge duplicates and fix Gordon's score

-- Step 1: Find all duplicate game_title_id pairs that should be merged
WITH duplicate_games AS (
  SELECT 
    name,
    COUNT(*) as dupe_count,
    MIN(id) as keep_id,  -- Keep the oldest entry
    ARRAY_AGG(id ORDER BY id) as all_ids
  FROM game_titles
  WHERE xbox_title_id IS NOT NULL
  GROUP BY name, xbox_title_id
  HAVING COUNT(*) > 1
),
ids_to_merge AS (
  SELECT 
    keep_id,
    UNNEST(all_ids) as merge_id
  FROM duplicate_games
  WHERE UNNEST(all_ids) != keep_id
)
-- Show what will be merged
SELECT 
  gt_keep.id as keep_id,
  gt_keep.name as game_name,
  gt_merge.id as merge_id,
  gt_keep.xbox_title_id,
  (SELECT COUNT(*) FROM user_games WHERE game_title_id = gt_merge.id) as affected_user_games,
  (SELECT COUNT(*) FROM achievements WHERE game_title_id = gt_merge.id) as affected_achievements
FROM ids_to_merge itm
JOIN game_titles gt_keep ON gt_keep.id = itm.keep_id
JOIN game_titles gt_merge ON gt_merge.id = itm.merge_id
ORDER BY affected_user_games DESC
LIMIT 50;
