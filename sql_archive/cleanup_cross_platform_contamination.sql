-- Clean up cross-platform contamination in game_titles
-- This removes achievements from "wrong" platforms, keeping each game_title single-platform

-- Step 1: Find game_titles with achievements from multiple platforms
WITH multi_platform_games AS (
  SELECT 
    gt.id as game_title_id,
    gt.name,
    gt.psn_npwr_id,
    gt.xbox_title_id,
    gt.steam_app_id,
    ARRAY_AGG(DISTINCT a.platform) as platforms,
    COUNT(DISTINCT a.platform) as platform_count
  FROM game_titles gt
  JOIN achievements a ON a.game_title_id = gt.id
  GROUP BY gt.id, gt.name, gt.psn_npwr_id, gt.xbox_title_id, gt.steam_app_id
  HAVING COUNT(DISTINCT a.platform) > 1
)
SELECT * FROM multi_platform_games
ORDER BY platform_count DESC, game_title_id;

-- Step 2: For each game_title, determine which platform it should keep
-- Rule: Keep the platform that matches the populated platform ID column
-- If multiple IDs populated (shouldn't happen), keep earliest achievements

-- This query shows what SHOULD be kept for each multi-platform game
WITH multi_platform_games AS (
  SELECT 
    gt.id as game_title_id,
    gt.name,
    gt.psn_npwr_id,
    gt.xbox_title_id,
    gt.steam_app_id,
    gt.created_at
  FROM game_titles gt
  JOIN achievements a ON a.game_title_id = gt.id
  GROUP BY gt.id, gt.name, gt.psn_npwr_id, gt.xbox_title_id, gt.steam_app_id, gt.created_at
  HAVING COUNT(DISTINCT a.platform) > 1
)
SELECT 
  game_title_id,
  name,
  CASE 
    WHEN psn_npwr_id IS NOT NULL THEN 'psn'
    WHEN xbox_title_id IS NOT NULL THEN 'xbox'
    WHEN steam_app_id IS NOT NULL THEN 'steam'
    ELSE 'unknown'
  END as keep_platform,
  psn_npwr_id,
  xbox_title_id,
  steam_app_id
FROM multi_platform_games
ORDER BY game_title_id;

-- Step 3: DELETE achievements from wrong platforms
-- For game_titles with PSN ID: delete Xbox and Steam achievements
DELETE FROM achievements
WHERE game_title_id IN (
  SELECT gt.id 
  FROM game_titles gt
  WHERE gt.psn_npwr_id IS NOT NULL
)
AND platform != 'psn';

-- For game_titles with Xbox ID: delete PSN and Steam achievements  
DELETE FROM achievements
WHERE game_title_id IN (
  SELECT gt.id 
  FROM game_titles gt
  WHERE gt.xbox_title_id IS NOT NULL
)
AND platform != 'xbox';

-- For game_titles with Steam ID: delete PSN and Xbox achievements
DELETE FROM achievements
WHERE game_title_id IN (
  SELECT gt.id 
  FROM game_titles gt
  WHERE gt.steam_app_id IS NOT NULL
)
AND platform != 'steam';

-- Verify cleanup
SELECT 
  'After cleanup: Multi-platform game_titles' as status,
  COUNT(*) as count
FROM (
  SELECT gt.id
  FROM game_titles gt
  JOIN achievements a ON a.game_title_id = gt.id
  GROUP BY gt.id
  HAVING COUNT(DISTINCT a.platform) > 1
) subquery;
