-- ============================================================================
-- CLEANUP SCRIPT: Remove Backwards Compatibility Duplicate Games
-- ============================================================================
-- This script removes duplicate game entries caused by backwards compatible
-- games appearing on multiple platforms (PS4/PS5, Xbox 360/One/Series X)
--
-- STRATEGY:
-- - Keep PS4 entries, delete PS5 duplicates
-- - Keep Xbox One entries, delete 360/Series X duplicates
-- - Only delete "bugs" (< 7 days between platforms)
-- - Preserve "legitimate stacks" (> 180 days between platforms)
-- ============================================================================

BEGIN;

-- ============================================================================
-- STEP 0: Identify games to delete (only bugs < 7 days)
-- ============================================================================
CREATE TEMP TABLE games_to_delete AS
-- PS5 duplicates (keep PS4)
SELECT DISTINCT 1 as platform_id, g_ps5.platform_game_id
FROM games g_ps5
JOIN games g_ps4 ON g_ps5.platform_game_id = g_ps4.platform_game_id
WHERE g_ps5.platform_id = 1 AND g_ps4.platform_id = 2
  AND EXISTS (
    SELECT 1
    FROM user_achievements ua_ps5
    JOIN user_achievements ua_ps4 ON ua_ps5.user_id = ua_ps4.user_id
      AND ua_ps5.platform_game_id = ua_ps4.platform_game_id
    WHERE ua_ps5.platform_id = 1 AND ua_ps4.platform_id = 2
      AND ua_ps5.platform_game_id = g_ps5.platform_game_id
      AND ABS(EXTRACT(EPOCH FROM (ua_ps5.earned_at - ua_ps4.earned_at))) < 604800
  )
UNION
-- Xbox Series X duplicates (keep Xbox One)
SELECT DISTINCT 12 as platform_id, g_series.platform_game_id
FROM games g_series
JOIN games g_one ON g_series.platform_game_id = g_one.platform_game_id
WHERE g_series.platform_id = 12 AND g_one.platform_id = 11
  AND EXISTS (
    SELECT 1
    FROM user_achievements ua_series
    JOIN user_achievements ua_one ON ua_series.user_id = ua_one.user_id
      AND ua_series.platform_game_id = ua_one.platform_game_id
    WHERE ua_series.platform_id = 12 AND ua_one.platform_id = 11
      AND ua_series.platform_game_id = g_series.platform_game_id
      AND ABS(EXTRACT(EPOCH FROM (ua_series.earned_at - ua_one.earned_at))) < 604800
  )
UNION
-- Xbox 360 duplicates (keep Xbox One)
SELECT DISTINCT 10 as platform_id, g_360.platform_game_id
FROM games g_360
JOIN games g_one ON g_360.platform_game_id = g_one.platform_game_id
WHERE g_360.platform_id = 10 AND g_one.platform_id = 11
  AND EXISTS (
    SELECT 1
    FROM user_achievements ua_360
    JOIN user_achievements ua_one ON ua_360.user_id = ua_one.user_id
      AND ua_360.platform_game_id = ua_one.platform_game_id
    WHERE ua_360.platform_id = 10 AND ua_one.platform_id = 11
      AND ua_360.platform_game_id = g_360.platform_game_id
      AND ABS(EXTRACT(EPOCH FROM (ua_360.earned_at - ua_one.earned_at))) < 604800
  );

-- ============================================================================
-- STEP 1: Delete ALL user_achievements for games to delete
-- ============================================================================
DELETE FROM user_achievements
WHERE (platform_id, platform_game_id) IN (
  SELECT platform_id, platform_game_id FROM games_to_delete
);

-- ============================================================================
-- STEP 2: Delete user_progress for games to delete
-- ============================================================================
DELETE FROM user_progress
WHERE (platform_id, platform_game_id) IN (
  SELECT platform_id, platform_game_id FROM games_to_delete
);

-- ============================================================================
-- STEP 3: Delete achievements definitions for games to delete
-- ============================================================================
DELETE FROM achievements
WHERE (platform_id, platform_game_id) IN (
  SELECT platform_id, platform_game_id FROM games_to_delete
);

-- ============================================================================
-- STEP 4: Delete duplicate game entries
-- ============================================================================
DELETE FROM games
WHERE (platform_id, platform_game_id) IN (
  SELECT platform_id, platform_game_id FROM games_to_delete
);

-- ============================================================================
-- VERIFICATION: Show how many records were affected
-- ============================================================================
SELECT 
  'Cleanup Complete' as status,
  (SELECT COUNT(*) FROM games WHERE platform_id IN (1,2,10,11,12)) as remaining_games,
  (SELECT COUNT(DISTINCT platform_game_id) FROM games WHERE platform_id IN (1,2,10,11,12)) as unique_games;

-- Uncomment the next line to commit the changes
-- COMMIT;

-- For safety, the transaction is left open. Review the results, then run:
-- COMMIT;   -- to save changes
-- ROLLBACK; -- to undo changes
