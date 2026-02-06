-- Simple comparison: Show PSN vs Xbox achievements for games you own on both platforms
-- Run this first to see if achievement names are similar enough for matching

WITH your_cross_platform_games AS (
  SELECT DISTINCT
    psn.name as game_name,
    psn.platform_game_id as psn_game_id,
    psn.platform_id as psn_platform_id,
    xbox.platform_game_id as xbox_game_id,
    xbox.platform_id as xbox_platform_id
  FROM games psn
  JOIN games xbox ON 
    REPLACE(LOWER(TRIM(psn.name)), ':', '') = REPLACE(LOWER(TRIM(xbox.name)), ':', '')
  WHERE psn.platform_id IN (1, 2)  -- PSN
    AND xbox.platform_id IN (10, 11, 12)  -- Xbox
)

-- Show game overview
SELECT 
  cpg.game_name,
  COUNT(DISTINCT CASE WHEN a.platform_id IN (1, 2) THEN a.platform_achievement_id END) as psn_achievement_count,
  COUNT(DISTINCT CASE WHEN a.platform_id IN (10, 11, 12) THEN a.platform_achievement_id END) as xbox_achievement_count,
  COUNT(DISTINCT CASE 
    WHEN a.platform_id IN (1, 2) AND a.metadata->>'dlc_name' IS NOT NULL 
    THEN a.metadata->>'dlc_name' 
  END) as psn_dlc_groups
FROM your_cross_platform_games cpg
LEFT JOIN achievements a ON 
  (a.platform_game_id = cpg.psn_game_id AND a.platform_id = cpg.psn_platform_id)
  OR (a.platform_game_id = cpg.xbox_game_id AND a.platform_id = cpg.xbox_platform_id)
GROUP BY cpg.game_name
ORDER BY psn_dlc_groups DESC, cpg.game_name;

-- Pick one game to examine in detail (replace 'GAME_NAME' with actual game)
-- SELECT 
--   'PSN' as platform,
--   a.name as achievement_name,
--   a.metadata->>'dlc_name' as dlc_group
-- FROM achievements a
-- JOIN games g ON a.platform_game_id = g.platform_game_id AND a.platform_id = g.platform_id
-- WHERE g.name ILIKE '%resident evil%'
--   AND g.platform_id IN (1, 2)
-- ORDER BY a.metadata->>'trophy_group_id', a.name
-- 
-- UNION ALL
-- 
-- SELECT 
--   'Xbox' as platform,
--   a.name as achievement_name,
--   a.metadata->>'dlc_name' as dlc_group
-- FROM achievements a
-- JOIN games g ON a.platform_game_id = g.platform_game_id AND a.platform_id = g.platform_id
-- WHERE g.name ILIKE '%resident evil%'
--   AND g.platform_id IN (10, 11, 12)
-- ORDER BY a.name;
