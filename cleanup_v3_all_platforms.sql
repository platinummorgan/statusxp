-- ============================================================================
-- CLEANUP V3: Remove ALL duplicates - keep OLDEST platform for each game_id
-- ============================================================================
-- Strategy: For each game_id that exists on multiple platforms,
-- keep the entry on the OLDEST/PRIMARY platform and delete all others
--
-- Priority order: PS3 (5) > PS4 (2) > Vita (9) > PS5 (1) > Xbox 360 (10) > Xbox One (11) > Series X (12) > Steam (4/5)
-- ============================================================================

BEGIN;

-- ============================================================================
-- STEP 1: Identify which platform to keep for each duplicate game_id
-- ============================================================================
CREATE TEMP TABLE games_to_keep AS
SELECT DISTINCT ON (platform_game_id)
  platform_id,
  platform_game_id
FROM games
WHERE platform_id IN (1, 2, 5, 9, 10, 11, 12, 4) -- All gaming platforms
ORDER BY 
  platform_game_id,
  CASE platform_id
    WHEN 5 THEN 1  -- PS3 priority 1
    WHEN 2 THEN 2  -- PS4 priority 2
    WHEN 9 THEN 3  -- Vita priority 3
    WHEN 10 THEN 4 -- Xbox 360 priority 4
    WHEN 11 THEN 5 -- Xbox One priority 5
    WHEN 4 THEN 6  -- Steam priority 6
    WHEN 1 THEN 7  -- PS5 priority 7
    WHEN 12 THEN 8 -- Series X priority 8
    ELSE 99
  END;

-- ============================================================================
-- STEP 2: Delete user_achievements for games NOT in keep list
-- ============================================================================
DELETE FROM user_achievements
WHERE (platform_id, platform_game_id) NOT IN (
  SELECT platform_id, platform_game_id FROM games_to_keep
)
AND platform_id IN (1, 2, 5, 9, 10, 11, 12, 4);

-- ============================================================================
-- STEP 3: Delete user_progress for games NOT in keep list
-- ============================================================================
DELETE FROM user_progress
WHERE (platform_id, platform_game_id) NOT IN (
  SELECT platform_id, platform_game_id FROM games_to_keep
)
AND platform_id IN (1, 2, 5, 9, 10, 11, 12, 4);

-- ============================================================================
-- STEP 4: Delete achievements definitions for games NOT in keep list
-- ============================================================================
DELETE FROM achievements
WHERE (platform_id, platform_game_id) NOT IN (
  SELECT platform_id, platform_game_id FROM games_to_keep
)
AND platform_id IN (1, 2, 5, 9, 10, 11, 12, 4);

-- ============================================================================
-- STEP 5: Delete game entries NOT in keep list
-- ============================================================================
DELETE FROM games
WHERE (platform_id, platform_game_id) NOT IN (
  SELECT platform_id, platform_game_id FROM games_to_keep
)
AND platform_id IN (1, 2, 5, 9, 10, 11, 12, 4);

-- ============================================================================
-- VERIFICATION: Show results
-- ============================================================================
SELECT 
  'Cleanup Complete' as status,
  (SELECT COUNT(*) FROM games WHERE platform_id IN (1,2,4,5,9,10,11,12)) as remaining_games,
  (SELECT COUNT(DISTINCT platform_game_id) FROM games WHERE platform_id IN (1,2,4,5,9,10,11,12)) as unique_games;

-- Run COMMIT; to save or ROLLBACK; to undo
