-- ============================================================================
-- CLEANUP V5: Delete ALL duplicate entries (all platforms)
-- ============================================================================
-- Strategy: If a game_id exists on multiple platforms, delete ALL of them
-- User will resync to recreate with correct duplicate prevention logic
-- ============================================================================

BEGIN;

-- ============================================================================
-- STEP 1: Identify ALL game_ids that exist on multiple platforms
-- ============================================================================
CREATE TEMP TABLE duplicate_game_ids AS
SELECT platform_game_id
FROM games
WHERE platform_id IN (1, 2, 4, 5, 9, 10, 11, 12)
GROUP BY platform_game_id
HAVING COUNT(DISTINCT platform_id) > 1;

-- ============================================================================
-- STEP 2: Delete user_achievements for ALL duplicate game_ids
-- ============================================================================
DELETE FROM user_achievements
WHERE platform_game_id IN (SELECT platform_game_id FROM duplicate_game_ids)
  AND platform_id IN (1, 2, 4, 5, 9, 10, 11, 12);

-- ============================================================================
-- STEP 3: Delete user_progress for ALL duplicate game_ids
-- ============================================================================
DELETE FROM user_progress
WHERE platform_game_id IN (SELECT platform_game_id FROM duplicate_game_ids)
  AND platform_id IN (1, 2, 4, 5, 9, 10, 11, 12);

-- ============================================================================
-- STEP 4: Delete achievements definitions for ALL duplicate game_ids
-- ============================================================================
DELETE FROM achievements
WHERE platform_game_id IN (SELECT platform_game_id FROM duplicate_game_ids)
  AND platform_id IN (1, 2, 4, 5, 9, 10, 11, 12);

-- ============================================================================
-- STEP 5: Delete ALL game entries for duplicate game_ids
-- ============================================================================
DELETE FROM games
WHERE platform_game_id IN (SELECT platform_game_id FROM duplicate_game_ids)
  AND platform_id IN (1, 2, 4, 5, 9, 10, 11, 12);

-- ============================================================================
-- VERIFICATION
-- ============================================================================
SELECT 
  'Cleanup Complete' as status,
  (SELECT COUNT(*) FROM games WHERE platform_id IN (1,2,4,5,9,10,11,12)) as remaining_games,
  (SELECT COUNT(DISTINCT platform_game_id) FROM games WHERE platform_id IN (1,2,4,5,9,10,11,12)) as unique_games;

-- Run COMMIT; then resync to recreate games with correct platforms
