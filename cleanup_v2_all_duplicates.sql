-- ============================================================================
-- CLEANUP SCRIPT V2: Remove ALL Backwards Compatibility Duplicates
-- ============================================================================
-- Previous script was too conservative - only deleted if users had achievements
-- on BOTH platforms. This deletes ALL newer platform entries that have older
-- platform equivalents, regardless of where achievements ended up.
--
-- STRATEGY:
-- - If game exists on PS4 AND PS5: delete PS5 (keep PS4)
-- - If game exists on Xbox One AND (360 OR Series X): delete 360/Series X (keep One)
-- ============================================================================

BEGIN;

-- ============================================================================
-- STEP 1: Delete user_achievements for duplicate games
-- ============================================================================
-- PS5 duplicates (ANY game that exists on both PS5 and PS4)
DELETE FROM user_achievements
WHERE platform_id = 1  -- PS5
  AND platform_game_id IN (
    SELECT DISTINCT g_ps5.platform_game_id
    FROM games g_ps5
    JOIN games g_ps4 ON g_ps5.platform_game_id = g_ps4.platform_game_id
    WHERE g_ps5.platform_id = 1 AND g_ps4.platform_id = 2
  );

-- Xbox Series X duplicates
DELETE FROM user_achievements
WHERE platform_id = 12  -- Xbox Series X
  AND platform_game_id IN (
    SELECT DISTINCT g_series.platform_game_id
    FROM games g_series
    JOIN games g_one ON g_series.platform_game_id = g_one.platform_game_id
    WHERE g_series.platform_id = 12 AND g_one.platform_id = 11
  );

-- Xbox 360 duplicates
DELETE FROM user_achievements
WHERE platform_id = 10  -- Xbox 360
  AND platform_game_id IN (
    SELECT DISTINCT g_360.platform_game_id
    FROM games g_360
    JOIN games g_one ON g_360.platform_game_id = g_one.platform_game_id
    WHERE g_360.platform_id = 10 AND g_one.platform_id = 11
  );

-- ============================================================================
-- STEP 2: Delete user_progress for duplicate games
-- ============================================================================
DELETE FROM user_progress
WHERE platform_id = 1  -- PS5
  AND platform_game_id IN (
    SELECT DISTINCT g_ps5.platform_game_id
    FROM games g_ps5
    JOIN games g_ps4 ON g_ps5.platform_game_id = g_ps4.platform_game_id
    WHERE g_ps5.platform_id = 1 AND g_ps4.platform_id = 2
  );

DELETE FROM user_progress
WHERE platform_id = 12  -- Xbox Series X
  AND platform_game_id IN (
    SELECT DISTINCT g_series.platform_game_id
    FROM games g_series
    JOIN games g_one ON g_series.platform_game_id = g_one.platform_game_id
    WHERE g_series.platform_id = 12 AND g_one.platform_id = 11
  );

DELETE FROM user_progress
WHERE platform_id = 10  -- Xbox 360
  AND platform_game_id IN (
    SELECT DISTINCT g_360.platform_game_id
    FROM games g_360
    JOIN games g_one ON g_360.platform_game_id = g_one.platform_game_id
    WHERE g_360.platform_id = 10 AND g_one.platform_id = 11
  );

-- ============================================================================
-- STEP 3: Delete achievements definitions
-- ============================================================================
DELETE FROM achievements
WHERE platform_id = 1  -- PS5
  AND platform_game_id IN (
    SELECT DISTINCT g_ps5.platform_game_id
    FROM games g_ps5
    JOIN games g_ps4 ON g_ps5.platform_game_id = g_ps4.platform_game_id
    WHERE g_ps5.platform_id = 1 AND g_ps4.platform_id = 2
  );

DELETE FROM achievements
WHERE platform_id = 12  -- Xbox Series X
  AND platform_game_id IN (
    SELECT DISTINCT g_series.platform_game_id
    FROM games g_series
    JOIN games g_one ON g_series.platform_game_id = g_one.platform_game_id
    WHERE g_series.platform_id = 12 AND g_one.platform_id = 11
  );

DELETE FROM achievements
WHERE platform_id = 10  -- Xbox 360
  AND platform_game_id IN (
    SELECT DISTINCT g_360.platform_game_id
    FROM games g_360
    JOIN games g_one ON g_360.platform_game_id = g_one.platform_game_id
    WHERE g_360.platform_id = 10 AND g_one.platform_id = 11
  );

-- ============================================================================
-- STEP 4: Delete duplicate game entries
-- ============================================================================
DELETE FROM games
WHERE platform_id = 1  -- PS5
  AND platform_game_id IN (
    SELECT DISTINCT g_ps5.platform_game_id
    FROM games g_ps5
    JOIN games g_ps4 ON g_ps5.platform_game_id = g_ps4.platform_game_id
    WHERE g_ps5.platform_id = 1 AND g_ps4.platform_id = 2
  );

DELETE FROM games
WHERE platform_id = 12  -- Xbox Series X
  AND platform_game_id IN (
    SELECT DISTINCT g_series.platform_game_id
    FROM games g_series
    JOIN games g_one ON g_series.platform_game_id = g_one.platform_game_id
    WHERE g_series.platform_id = 12 AND g_one.platform_id = 11
  );

DELETE FROM games
WHERE platform_id = 10  -- Xbox 360
  AND platform_game_id IN (
    SELECT DISTINCT g_360.platform_game_id
    FROM games g_360
    JOIN games g_one ON g_360.platform_game_id = g_one.platform_game_id
    WHERE g_360.platform_id = 10 AND g_one.platform_id = 11
  );

-- ============================================================================
-- VERIFICATION: Show results
-- ============================================================================
SELECT 
  'Cleanup Complete' as status,
  (SELECT COUNT(*) FROM games WHERE platform_id IN (1,2,10,11,12)) as remaining_games,
  (SELECT COUNT(DISTINCT platform_game_id) FROM games WHERE platform_id IN (1,2,10,11,12)) as unique_games;

-- Run COMMIT; to save or ROLLBACK; to undo
