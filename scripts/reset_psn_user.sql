-- ============================================================================
-- RESET PSN DATA FOR SINGLE USER
-- ============================================================================
-- 
-- WARNING: This script DELETES all PSN achievement and progress data for
-- a specific user. Use with caution!
--
-- USAGE:
--   1. Replace {{USER_ID}} with the actual UUID of the user
--   2. Review the SELECT queries first to verify what will be deleted
--   3. Run the DELETE statements
--
-- PLATFORM IDs:
--   PS5 = 1, PS4 = 2, PS3 = 5, PSVITA = 9
--
-- ============================================================================

-- Step 1: PREVIEW - Check what will be deleted (run this first)
-- ============================================================================

-- Preview achievements to be deleted
SELECT 
  ua.user_id,
  p.name as platform_name,
  COUNT(*) as achievement_count
FROM user_achievements ua
JOIN platforms p ON p.id = ua.platform_id
WHERE ua.user_id = '{{USER_ID}}'
  AND ua.platform_id IN (1, 2, 5, 9)  -- PSN platforms only
GROUP BY ua.user_id, p.name
ORDER BY p.name;

-- Preview progress to be deleted
SELECT 
  up.user_id,
  p.name as platform_name,
  COUNT(*) as game_count
FROM user_progress up
JOIN platforms p ON p.id = up.platform_id
WHERE up.user_id = '{{USER_ID}}'
  AND up.platform_id IN (1, 2, 5, 9)  -- PSN platforms only
GROUP BY up.user_id, p.name
ORDER BY p.name;


-- Step 2: DELETE - Execute these to permanently remove PSN data
-- ============================================================================

-- WARNING: Deletes all earned achievements for this user on PSN platforms
-- Affects: PS5 (1), PS4 (2), PS3 (5), PSVITA (9)
DELETE FROM user_achievements 
WHERE user_id = '{{USER_ID}}' 
  AND platform_id IN (1, 2, 5, 9);

-- WARNING: Deletes all game progress for this user on PSN platforms  
-- Affects: PS5 (1), PS4 (2), PS3 (5), PSVITA (9)
DELETE FROM user_progress 
WHERE user_id = '{{USER_ID}}' 
  AND platform_id IN (1, 2, 5, 9);


-- Step 3: VERIFY - Confirm deletion was successful
-- ============================================================================

-- Should return 0 rows if deletion was complete
SELECT COUNT(*) as remaining_achievements
FROM user_achievements
WHERE user_id = '{{USER_ID}}' 
  AND platform_id IN (1, 2, 5, 9);

SELECT COUNT(*) as remaining_progress
FROM user_progress
WHERE user_id = '{{USER_ID}}' 
  AND platform_id IN (1, 2, 5, 9);


-- ============================================================================
-- NOTES:
-- ============================================================================
--
-- This script does NOT delete:
-- - User profile data (profiles table)
-- - User's PSN authentication tokens
-- - Xbox or Steam data (platform_id 4, 10, 11, 12)
-- - Game or achievement definitions (games, achievements tables)
--
-- After deletion, the user can re-sync their PSN account to repopulate data
-- with corrected platform assignments.
--
-- ============================================================================
