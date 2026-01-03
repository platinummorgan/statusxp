-- Delete duplicate game_titles (keeping oldest entry per platform ID)
-- CASCADE will automatically delete related achievements and user_games

-- Step 1: Review what will be deleted
-- PSN Duplicate: Overcooked (NPWR11263_00)
-- Keeping: game_title_id 265 (created 2025-12-07 22:41:58)
-- Deleting: 362, 2447, 2454, 2455, 2459, 2527, 2529, 2530

SELECT 
  id,
  name,
  psn_npwr_id,
  created_at,
  (SELECT COUNT(*) FROM achievements WHERE game_title_id = gt.id) as achievement_count,
  (SELECT COUNT(*) FROM user_games WHERE game_title_id = gt.id) as user_game_count
FROM game_titles gt
WHERE id IN (362, 2447, 2454, 2455, 2459, 2527, 2529, 2530)
ORDER BY created_at;

-- Step 2: DELETE duplicate game_titles (CASCADE will delete related records)
DELETE FROM game_titles
WHERE id IN (362, 2447, 2454, 2455, 2459, 2527, 2529, 2530);

-- Step 3: Verify no duplicates remain
-- Should return 0 rows after deletion
SELECT 
  psn_npwr_id,
  COUNT(*) as duplicate_count,
  ARRAY_AGG(id) as game_title_ids
FROM game_titles
WHERE psn_npwr_id IS NOT NULL
GROUP BY psn_npwr_id
HAVING COUNT(*) > 1;

SELECT 
  xbox_title_id,
  COUNT(*) as duplicate_count,
  ARRAY_AGG(id) as game_title_ids
FROM game_titles
WHERE xbox_title_id IS NOT NULL
GROUP BY xbox_title_id
HAVING COUNT(*) > 1;

SELECT 
  steam_app_id,
  COUNT(*) as duplicate_count,
  ARRAY_AGG(id) as game_title_ids
FROM game_titles
WHERE steam_app_id IS NOT NULL
GROUP BY steam_app_id
HAVING COUNT(*) > 1;

-- Step 4: Final summary
SELECT 
  'Total game_titles' as metric,
  COUNT(*) as count
FROM game_titles
UNION ALL
SELECT 
  'PSN game_titles' as metric,
  COUNT(*) as count
FROM game_titles
WHERE psn_npwr_id IS NOT NULL
UNION ALL
SELECT 
  'Xbox game_titles' as metric,
  COUNT(*) as count
FROM game_titles
WHERE xbox_title_id IS NOT NULL
UNION ALL
SELECT 
  'Steam game_titles' as metric,
  COUNT(*) as count
FROM game_titles
WHERE steam_app_id IS NOT NULL;
