-- ============================================
-- DATABASE CORRUPTION FIX SCRIPT
-- Addresses 3 critical issues found in audit:
-- 1. Platform mismatches (870+ records)
-- 2. Missing user_games entries (400+ records)
-- 3. Missing has_platinum flags (101 records)
-- ============================================
-- IMPORTANT: Database currently has UNIQUE(user_id, game_title_id) constraint
--            Users can only have ONE entry per game (not one per platform)
--            This means we need to be VERY careful about multi-platform games
-- ============================================

-- Start transaction for safety
BEGIN;

-- ============================================
-- PRE-CHECK: Detect multi-platform game ownership
-- Users who have BOTH PSN and Xbox/Steam achievements for same game
-- ============================================
SELECT 
  'MULTI_PLATFORM_CHECK' as check_type,
  p.psn_online_id,
  gt.name as game_name,
  COUNT(DISTINCT a.platform) as platforms_count,
  ARRAY_AGG(DISTINCT a.platform) as platforms
FROM user_achievements ua
JOIN achievements a ON a.id = ua.achievement_id
JOIN game_titles gt ON gt.id = a.game_title_id
JOIN profiles p ON p.id = ua.user_id
GROUP BY p.psn_online_id, gt.name, p.id, gt.id, ua.user_id
HAVING COUNT(DISTINCT a.platform) > 1
ORDER BY platforms_count DESC;

-- ============================================
-- FIX 1: Correct platform_id mismatches (SAFER APPROACH)
-- Only change platform_id if user ONLY has PSN achievements (not multi-platform)
-- ============================================

-- Preview: Show what will be fixed
SELECT 
  'PREVIEW: Safe Platform Mismatch Fix' as action,
  COUNT(*) as records_to_fix
FROM user_games ug
WHERE ug.platform_id != 1
  -- User has PSN achievements for this game
  AND EXISTS (
    SELECT 1 FROM user_achievements ua
    JOIN achievements a ON a.id = ua.achievement_id
    WHERE a.platform = 'psn'
      AND ua.user_id = ug.user_id
      AND a.game_title_id = ug.game_title_id
  )
  -- User does NOT have Xbox/Steam achievements for this game
  AND NOT EXISTS (
    SELECT 1 FROM user_achievements ua
    JOIN achievements a ON a.id = ua.achievement_id
    WHERE a.platform IN ('xbox', 'steam')
      AND ua.user_id = ug.user_id
      AND a.game_title_id = ug.game_title_id
  );

-- Apply safe fix: Only update if user ONLY owns game on PSN
UPDATE user_games ug
SET platform_id = 1,
    updated_at = NOW()
WHERE ug.platform_id != 1
  -- User has PSN achievements for this game
  AND EXISTS (
    SELECT 1 FROM user_achievements ua
    JOIN achievements a ON a.id = ua.achievement_id
    WHERE a.platform = 'psn'
      AND ua.user_id = ug.user_id
      AND a.game_title_id = ug.game_title_id
  )
  -- User does NOT have Xbox/Steam achievements for this game
  AND NOT EXISTS (
    SELECT 1 FROM user_achievements ua
    JOIN achievements a ON a.id = ua.achievement_id
    WHERE a.platform IN ('xbox', 'steam')
      AND ua.user_id = ug.user_id
      AND a.game_title_id = ug.game_title_id
  );

-- Verify the fix
SELECT 
  'RESULT: Safe Platform Mismatch Fixed' as action,
  COUNT(*) as records_fixed
FROM user_games ug
WHERE ug.platform_id = 1
  AND ug.updated_at >= NOW() - INTERVAL '1 minute';

-- ============================================
-- MULTI-PLATFORM CONFLICT REPORT
-- Games where we CAN'T safely fix because user owns on multiple platforms
-- These need manual review or schema change (allow multiple entries per game)
-- ============================================
SELECT 
  'MULTI_PLATFORM_CONFLICTS' as issue_type,
  p.psn_online_id,
  gt.name as game_name,
  ug.platform_id as current_platform_id,
  CASE ug.platform_id 
    WHEN 1 THEN 'PSN'
    WHEN 2 THEN 'Xbox'
    WHEN 3 THEN 'Steam'
    WHEN 5 THEN 'PS3'
    WHEN 11 THEN 'Unknown'
  END as current_platform,
  ARRAY_AGG(DISTINCT a.platform) as achievement_platforms,
  COUNT(DISTINCT a.platform) as platform_count
FROM user_games ug
JOIN profiles p ON p.id = ug.user_id
JOIN game_titles gt ON gt.id = ug.game_title_id
JOIN user_achievements ua ON ua.user_id = ug.user_id
JOIN achievements a ON a.id = ua.achievement_id AND a.game_title_id = ug.game_title_id
WHERE ug.platform_id != 1
  AND EXISTS (
    SELECT 1 FROM user_achievements ua2
    JOIN achievements a2 ON a2.id = ua2.achievement_id
    WHERE a2.platform = 'psn'
      AND ua2.user_id = ug.user_id
      AND a2.game_title_id = ug.game_title_id
  )
  AND EXISTS (
    SELECT 1 FROM user_achievements ua3
    JOIN achievements a3 ON a3.id = ua3.achievement_id
    WHERE a3.platform IN ('xbox', 'steam')
      AND ua3.user_id = ug.user_id
      AND a3.game_title_id = ug.game_title_id
  )
GROUP BY p.psn_online_id, gt.name, ug.platform_id, p.id, gt.id
ORDER BY p.psn_online_id, gt.name;

-- ============================================
-- FIX 2: Create missing user_games entries
-- IMPORTANT: Can only create if user doesn't already have entry for this game
-- Due to UNIQUE(user_id, game_title_id) constraint, we can't have multiple platforms
-- ============================================

-- Preview what we're creating
SELECT 
  'PREVIEW: Missing user_games Creation' as action,
  COUNT(DISTINCT ua.user_id || '-' || a.game_title_id) as records_to_create
FROM user_achievements ua
JOIN achievements a ON a.id = ua.achievement_id
WHERE a.platform = 'psn'
  AND NOT EXISTS (
    SELECT 1 FROM user_games ug
    WHERE ug.user_id = ua.user_id
      AND ug.game_title_id = a.game_title_id
      -- NO platform_id check - check if ANY entry exists
  );

-- Create missing user_games entries with calculated stats
-- Only inserts where NO entry exists (regardless of platform)
INSERT INTO user_games (
  user_id,
  game_title_id,
  platform_id,
  earned_trophies,
  total_trophies,
  completion_percent,
  bronze_trophies,
  silver_trophies,
  gold_trophies,
  platinum_trophies,
  has_platinum,
  last_trophy_earned_at,
  created_at,
  updated_at
)
SELECT DISTINCT
  ua.user_id,
  a.game_title_id,
  1 as platform_id, -- PSN
  COUNT(ua.id) as earned_trophies,
  (SELECT COUNT(*) FROM achievements WHERE game_title_id = a.game_title_id AND platform = 'psn') as total_trophies,
  ROUND((COUNT(ua.id)::numeric / NULLIF((SELECT COUNT(*) FROM achievements WHERE game_title_id = a.game_title_id AND platform = 'psn'), 0)) * 100, 2) as completion_percent,
  COUNT(CASE WHEN a.psn_trophy_type = 'bronze' THEN 1 END) as bronze_trophies,
  COUNT(CASE WHEN a.psn_trophy_type = 'silver' THEN 1 END) as silver_trophies,
  COUNT(CASE WHEN a.psn_trophy_type = 'gold' THEN 1 END) as gold_trophies,
  COUNT(CASE WHEN a.psn_trophy_type = 'platinum' THEN 1 END) as platinum_trophies,
  BOOL_OR(a.psn_trophy_type = 'platinum') as has_platinum,
  MAX(ua.unlocked_at) as last_trophy_earned_at,
  NOW() as created_at,
  NOW() as updated_at
FROM user_achievements ua
JOIN achievements a ON a.id = ua.achievement_id
WHERE a.platform = 'psn'
  AND NOT EXISTS (
    SELECT 1 FROM user_games ug
    WHERE ug.user_id = ua.user_id
      AND ug.game_title_id = a.game_title_id
      -- NO platform_id check - prevents duplicate key violation
  )
GROUP BY ua.user_id, a.game_title_id;

-- Verify creation
SELECT 
  'RESULT: Missing user_games Created' as action,
  COUNT(*) as records_created
FROM user_games
WHERE created_at >= NOW() - INTERVAL '1 minute';

-- ============================================
-- FIX 3: Update missing has_platinum flags
-- Set has_platinum=true where user has earned a platinum trophy
-- ============================================

-- Preview platinum flag updates
SELECT 
  'PREVIEW: has_platinum Flag Updates' as action,
  COUNT(DISTINCT ug.id) as records_to_update
FROM user_games ug
WHERE ug.platform_id = 1
  AND (ug.has_platinum = false OR ug.has_platinum IS NULL)
  AND EXISTS (
    SELECT 1 FROM user_achievements ua
    JOIN achievements a ON a.id = ua.achievement_id
    WHERE ua.user_id = ug.user_id
      AND a.game_title_id = ug.game_title_id
      AND a.psn_trophy_type = 'platinum'
      AND a.platform = 'psn'
  );

-- Update has_platinum flag
UPDATE user_games ug
SET has_platinum = true,
    platinum_trophies = 1,
    updated_at = NOW()
WHERE ug.platform_id = 1
  AND (ug.has_platinum = false OR ug.has_platinum IS NULL)
  AND EXISTS (
    SELECT 1 FROM user_achievements ua
    JOIN achievements a ON a.id = ua.achievement_id
    WHERE ua.user_id = ug.user_id
      AND a.game_title_id = ug.game_title_id
      AND a.psn_trophy_type = 'platinum'
      AND a.platform = 'psn'
  );

-- Verify updates
SELECT 
  'RESULT: has_platinum Flags Updated' as action,
  COUNT(*) as records_updated
FROM user_games
WHERE has_platinum = true
  AND updated_at >= NOW() - INTERVAL '1 minute';

-- ============================================
-- FINAL VERIFICATION: Re-run audit checks
-- ============================================

-- Check for remaining platform mismatches
SELECT 
  'VERIFICATION: Remaining Platform Mismatches' as check_type,
  COUNT(*) as remaining_issues
FROM user_games ug
WHERE EXISTS (
  SELECT 1 FROM user_achievements ua
  JOIN achievements a ON a.id = ua.achievement_id
  WHERE a.platform = 'psn'
    AND ua.user_id = ug.user_id
    AND a.game_title_id = ug.game_title_id
)
AND ug.platform_id != 1;

-- Check for remaining missing user_games
SELECT 
  'VERIFICATION: Remaining Missing user_games' as check_type,
  COUNT(DISTINCT ua.user_id || '-' || a.game_title_id) as remaining_issues
FROM user_achievements ua
JOIN achievements a ON a.id = ua.achievement_id
WHERE a.platform = 'psn'
  AND NOT EXISTS (
    SELECT 1 FROM user_games ug
    WHERE ug.user_id = ua.user_id
      AND ug.game_title_id = a.game_title_id
      AND ug.platform_id = 1
  );

-- Check for remaining missing has_platinum flags
SELECT 
  'VERIFICATION: Remaining Missing has_platinum Flags' as check_type,
  COUNT(DISTINCT ug.id) as remaining_issues
FROM user_games ug
WHERE ug.platform_id = 1
  AND (ug.has_platinum = false OR ug.has_platinum IS NULL)
  AND EXISTS (
    SELECT 1 FROM user_achievements ua
    JOIN achievements a ON a.id = ua.achievement_id
    WHERE ua.user_id = ug.user_id
      AND a.game_title_id = ug.game_title_id
      AND a.psn_trophy_type = 'platinum'
      AND a.platform = 'psn'
  );

-- ============================================
-- COMMIT OR ROLLBACK
-- Review the verification results above.
-- If everything looks good, COMMIT.
-- If there are issues, ROLLBACK.
-- ============================================

-- Uncomment ONE of these lines after reviewing:
-- COMMIT;
-- ROLLBACK;

SELECT 'Fix script complete. Review verification results and commit/rollback transaction.' as status;

-- ============================================
-- IMPORTANT NOTES FOR FUTURE
-- ============================================
-- Current database constraint: UNIQUE(user_id, game_title_id)
-- This means users can only have ONE entry per game (not one per platform)
--
-- This fix script handles THREE scenarios:
-- 1. PSN-only games with wrong platform_id → Fixed by updating platform_id to PSN
-- 2. Multi-platform games (PSN + Xbox/Steam) → Reported but NOT fixed (would require schema change)
-- 3. Missing user_games entries → Created ONLY if no entry exists for that game
--
-- RECOMMENDED LONG-TERM FIX:
-- Change constraint to UNIQUE(user_id, game_title_id, platform_id)
-- This would allow users to own the same game on multiple platforms
-- Migration would need to:
--   1. Drop old UNIQUE constraint
--   2. Split multi-platform games into separate entries
--   3. Add new UNIQUE constraint
--   4. Update all sync services to handle multi-platform properly

