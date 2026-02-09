-- Compare achievement names between PSN and Xbox for the same game
-- This helps determine if cross-platform DLC matching is viable

-- First, find games that exist on both PSN and Xbox (by similar names)
WITH cross_platform_games AS (
  SELECT DISTINCT
    psn.name as game_name,
    psn.platform_game_id as psn_game_id,
    psn.platform_id as psn_platform_id,
    xbox.platform_game_id as xbox_game_id,
    xbox.platform_id as xbox_platform_id
  FROM games psn
  JOIN games xbox ON LOWER(TRIM(psn.name)) = LOWER(TRIM(xbox.name))
  WHERE psn.platform_id IN (1, 2)  -- PSN platforms (PS4=1, PS5=2)
    AND xbox.platform_id IN (10, 11, 12)  -- Xbox platforms
  LIMIT 20  -- Start with 20 games
),

-- Get PSN achievements with DLC info
psn_achievements AS (
  SELECT 
    cpg.game_name,
    cpg.psn_game_id,
    a.name as achievement_name,
    a.description,
    a.metadata->>'dlc_name' as dlc_name,
    a.metadata->>'is_dlc' as is_dlc,
    a.metadata->>'trophy_group_id' as trophy_group_id
  FROM cross_platform_games cpg
  JOIN achievements a ON a.platform_game_id = cpg.psn_game_id 
    AND a.platform_id = cpg.psn_platform_id
),

-- Get Xbox achievements
xbox_achievements AS (
  SELECT 
    cpg.game_name,
    cpg.xbox_game_id,
    a.name as achievement_name,
    a.description,
    a.metadata->>'dlc_name' as dlc_name,
    a.metadata->>'is_dlc' as is_dlc
  FROM cross_platform_games cpg
  JOIN achievements a ON a.platform_game_id = cpg.xbox_game_id 
    AND a.platform_id = cpg.xbox_platform_id
)

-- Show side-by-side comparison
SELECT 
  pa.game_name,
  pa.dlc_name as psn_dlc_group,
  pa.achievement_name as psn_achievement,
  xa.achievement_name as xbox_achievement,
  -- Calculate similarity (simple length comparison for now)
  CASE 
    WHEN pa.achievement_name = xa.achievement_name THEN '✅ EXACT MATCH'
    WHEN LOWER(pa.achievement_name) = LOWER(xa.achievement_name) THEN '✓ Case difference only'
    WHEN similarity(pa.achievement_name, xa.achievement_name) > 0.8 THEN '~~ Very Similar'
    WHEN similarity(pa.achievement_name, xa.achievement_name) > 0.6 THEN '~ Somewhat Similar'
    ELSE '❌ Different'
  END as match_quality
FROM psn_achievements pa
LEFT JOIN xbox_achievements xa ON pa.game_name = xa.game_name
  AND similarity(pa.achievement_name, xa.achievement_name) > 0.5
ORDER BY pa.game_name, pa.dlc_name NULLS FIRST, pa.achievement_name;

-- Summary statistics
SELECT 
  'Total cross-platform games found' as metric,
  COUNT(DISTINCT game_name) as count
FROM cross_platform_games

UNION ALL

SELECT 
  'Games with PSN DLC groups' as metric,
  COUNT(DISTINCT game_name) as count
FROM psn_achievements
WHERE dlc_name IS NOT NULL;
