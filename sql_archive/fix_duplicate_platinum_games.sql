-- Fix duplicate platinum games for user 68dd426c-3ce9-45e0-a9e6-70a9d3127eb8
-- Issue: Same game (same platform_game_id) synced to multiple platform_ids
-- These are NOT cross-gen versions - they're the SAME trophy set tracked multiple times
-- Root cause: PSN sync didn't deduplicate games by npCommunicationId before processing

-- Step 1: Identify duplicates (same platform_game_id on multiple platform_ids)
WITH duplicate_games AS (
  SELECT 
    g.platform_game_id,
    g.name,
    array_agg(g.platform_id ORDER BY g.platform_id) as platform_ids,
    array_agg(CASE g.platform_id
      WHEN 1 THEN 'PS5'
      WHEN 2 THEN 'PS4'
      WHEN 5 THEN 'PS3'
      WHEN 9 THEN 'PSVITA'
    END ORDER BY g.platform_id) as platform_names
  FROM games g
  WHERE EXISTS (
    SELECT 1 FROM user_achievements ua
    WHERE ua.user_id = '68dd426c-3ce9-45e0-a9e6-70a9d3127eb8'
      AND ua.platform_id = g.platform_id
      AND ua.platform_game_id = g.platform_game_id
  )
  GROUP BY g.platform_game_id, g.name
  HAVING COUNT(DISTINCT g.platform_id) > 1
)
SELECT * FROM duplicate_games
ORDER BY name;

-- Step 2: For each duplicate platform_game_id, keep ONLY the newest platform_id
-- Delete older platform_id versions (PS5=1 is newest, PS4=2, PS3=5, Vita=9)

-- Batch 1: Delete first 8 games (PS4/PS3 versions)
DELETE FROM user_achievements
WHERE user_id = '68dd426c-3ce9-45e0-a9e6-70a9d3127eb8'
  AND platform_id IN (2, 5)
  AND platform_game_id IN (
    'NPWR01864_00', 'NPWR14751_00', 'NPWR11243_00', 'NPWR13826_00', 
    'NPWR05424_00', 'NPWR08899_00', 'NPWR06804_00', 'NPWR15120_00'
  );

DELETE FROM user_progress
WHERE user_id = '68dd426c-3ce9-45e0-a9e6-70a9d3127eb8'
  AND platform_id IN (2, 5)
  AND platform_game_id IN (
    'NPWR01864_00', 'NPWR14751_00', 'NPWR11243_00', 'NPWR13826_00', 
    'NPWR05424_00', 'NPWR08899_00', 'NPWR06804_00', 'NPWR15120_00'
  );

-- Batch 2: Delete next 8 games
DELETE FROM user_achievements
WHERE user_id = '68dd426c-3ce9-45e0-a9e6-70a9d3127eb8'
  AND platform_id IN (2, 5)
  AND platform_game_id IN (
    'NPWR01730_00', 'NPWR06685_00', 'NPWR09167_00', 'NPWR05403_00',
    'NPWR15142_00', 'NPWR06063_00', 'NPWR08983_00', 'NPWR19151_00'
  );

DELETE FROM user_progress
WHERE user_id = '68dd426c-3ce9-45e0-a9e6-70a9d3127eb8'
  AND platform_id IN (2, 5)
  AND platform_game_id IN (
    'NPWR01730_00', 'NPWR06685_00', 'NPWR09167_00', 'NPWR05403_00',
    'NPWR15142_00', 'NPWR06063_00', 'NPWR08983_00', 'NPWR19151_00'
  );

-- Batch 3: Delete remaining 8 games
DELETE FROM user_achievements
WHERE user_id = '68dd426c-3ce9-45e0-a9e6-70a9d3127eb8'
  AND platform_id IN (2, 5)
  AND platform_game_id IN (
    'NPWR07942_00', 'NPWR11469_00', 'NPWR13348_00', 'NPWR06616_00',
    'NPWR07242_00', 'NPWR07290_00', 'NPWR10664_00', 'NPWR06040_00'
  );

DELETE FROM user_progress
WHERE user_id = '68dd426c-3ce9-45e0-a9e6-70a9d3127eb8'
  AND platform_id IN (2, 5)
  AND platform_game_id IN (
    'NPWR07942_00', 'NPWR11469_00', 'NPWR13348_00', 'NPWR06616_00',
    'NPWR07242_00', 'NPWR07290_00', 'NPWR10664_00', 'NPWR06040_00'
  );

-- Verify the fix
SELECT 
  COUNT(*) as remaining_platinums
FROM user_achievements ua
JOIN achievements a 
  ON a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id 
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = '68dd426c-3ce9-45e0-a9e6-70a9d3127eb8'
  AND a.is_platinum = true;

-- Check for any remaining duplicates (should be 0)
WITH remaining_duplicates AS (
  SELECT 
    g.platform_game_id,
    g.name,
    COUNT(DISTINCT g.platform_id) as platform_count
  FROM games g
  WHERE EXISTS (
    SELECT 1 FROM user_achievements ua
    WHERE ua.user_id = '68dd426c-3ce9-45e0-a9e6-70a9d3127eb8'
      AND ua.platform_id = g.platform_id
      AND ua.platform_game_id = g.platform_game_id
  )
  GROUP BY g.platform_game_id, g.name
  HAVING COUNT(DISTINCT g.platform_id) > 1
)
SELECT * FROM remaining_duplicates;
