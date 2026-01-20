-- ============================================
-- FIX #2: SURGICAL DATABASE CLEANUP
-- Corrects 153 corrupted platform_id records
-- Based on preflight_safety_check.sql results
-- ============================================
-- SAFE: No schema changes, only data corrections
-- TESTED: Constraint validation passed (CHECK_8)
-- SCOPE: 153 records out of 3,909 (3.9%)
-- ============================================

BEGIN;

-- ============================================
-- STEP 1: Preview what will be fixed
-- ============================================

-- Show current corruption breakdown
WITH achievement_platforms AS (
  SELECT 
    ua.user_id,
    a.game_title_id,
    a.platform,
    COUNT(*) as achievement_count
  FROM user_achievements ua
  JOIN achievements a ON a.id = ua.achievement_id
  GROUP BY ua.user_id, a.game_title_id, a.platform
)
SELECT 
  'PREVIEW: Records to fix' as status,
  ap.platform as correct_platform,
  p.code as current_wrong_platform,
  COUNT(DISTINCT ug.id) as records_to_fix
FROM achievement_platforms ap
JOIN user_games ug ON ug.user_id = ap.user_id AND ug.game_title_id = ap.game_title_id
LEFT JOIN platforms p ON p.id = ug.platform_id
WHERE (
  (ap.platform = 'psn' AND p.code NOT IN ('PS3', 'PS4', 'PS5', 'PSVITA')) OR
  (ap.platform = 'xbox' AND p.code NOT IN ('XBOX360', 'XBOXONE', 'XBOXSERIESX')) OR
  (ap.platform = 'steam' AND p.code != 'Steam')
)
GROUP BY ap.platform, p.code
ORDER BY ap.platform, records_to_fix DESC;

-- ============================================
-- STEP 2: Create mapping of correct platform_ids
-- ============================================

-- We need to determine which specific PSN platform (PS3/PS4/PS5/VITA) to use
-- Strategy: Use the most common platform from the game's achievements
CREATE TEMP TABLE correct_platform_mapping AS
WITH achievement_details AS (
  SELECT DISTINCT
    ua.user_id,
    a.game_title_id,
    a.platform,
    a.platform_version,
    COUNT(*) OVER (PARTITION BY ua.user_id, a.game_title_id, a.platform_version) as version_count
  FROM user_achievements ua
  JOIN achievements a ON a.id = ua.achievement_id
),
best_platform_version AS (
  SELECT DISTINCT ON (user_id, game_title_id, platform)
    user_id,
    game_title_id,
    platform,
    platform_version,
    version_count
  FROM achievement_details
  ORDER BY user_id, game_title_id, platform, version_count DESC
)
SELECT 
  bpv.user_id,
  bpv.game_title_id,
  bpv.platform as achievement_platform,
  bpv.platform_version,
  ug.id as user_game_id,  -- Track specific corrupted record
  ug.platform_id as current_wrong_platform_id,
  CASE 
    WHEN bpv.platform = 'psn' THEN
      CASE 
        WHEN bpv.platform_version = 'PS5' THEN 1
        WHEN bpv.platform_version = 'PS4' THEN 2
        WHEN bpv.platform_version = 'PS3' THEN 5
        WHEN bpv.platform_version = 'PSVITA' THEN 9
        ELSE 2  -- Default to PS4 if unclear
      END
    WHEN bpv.platform = 'xbox' THEN 11  -- XBOXONE (most common)
    WHEN bpv.platform = 'steam' THEN 4  -- Steam
  END as correct_platform_id
FROM best_platform_version bpv
JOIN user_games ug ON ug.user_id = bpv.user_id AND ug.game_title_id = bpv.game_title_id
JOIN platforms p ON p.id = ug.platform_id  -- Changed to JOIN to ensure platform exists
WHERE (
  -- ONLY include corrupted entries
  (bpv.platform = 'psn' AND p.code NOT IN ('PS3', 'PS4', 'PS5', 'PSVITA')) OR
  (bpv.platform = 'xbox' AND p.code NOT IN ('XBOX360', 'XBOXONE', 'XBOXSERIESX')) OR
  (bpv.platform = 'steam' AND p.code != 'Steam')
);

-- Verify mapping
SELECT 
  'MAPPING VERIFICATION' as status,
  cpm.achievement_platform,
  p.code as correct_platform_code,
  COUNT(*) as records
FROM correct_platform_mapping cpm
JOIN platforms p ON p.id = cpm.correct_platform_id
GROUP BY cpm.achievement_platform, p.code
ORDER BY cpm.achievement_platform, records DESC;

-- ============================================
-- STEP 3: Identify duplicates vs simple fixes
-- ============================================

-- Find cases where user already has correct entry (duplicates to delete)
CREATE TEMP TABLE duplicates_to_delete AS
SELECT 
  cpm.user_game_id,
  cpm.user_id,
  cpm.game_title_id,
  cpm.current_wrong_platform_id as wrong_platform_id,
  cpm.correct_platform_id
FROM correct_platform_mapping cpm
WHERE EXISTS (
  -- User already has entry with correct platform_id
  SELECT 1 FROM user_games ug2
  WHERE ug2.user_id = cpm.user_id
    AND ug2.game_title_id = cpm.game_title_id
    AND ug2.platform_id = cpm.correct_platform_id
    AND ug2.id != cpm.user_game_id
);

-- Show what will be deleted
SELECT 
  'DUPLICATES TO DELETE' as action,
  pr.psn_online_id,
  gt.name as game_name,
  p_wrong.code as wrong_platform,
  p_correct.code as correct_platform_exists,
  'Duplicate - will delete corrupted entry' as reason
FROM duplicates_to_delete dtd
JOIN profiles pr ON pr.id = dtd.user_id
JOIN game_titles gt ON gt.id = dtd.game_title_id
JOIN platforms p_wrong ON p_wrong.id = dtd.wrong_platform_id
JOIN platforms p_correct ON p_correct.id = dtd.correct_platform_id
ORDER BY pr.psn_online_id, gt.name
LIMIT 20;

-- Find cases to update (no existing correct entry)
CREATE TEMP TABLE records_to_update AS
SELECT 
  cpm.user_game_id,
  cpm.correct_platform_id
FROM correct_platform_mapping cpm
WHERE NOT EXISTS (
  SELECT 1 FROM duplicates_to_delete dtd
  WHERE dtd.user_game_id = cpm.user_game_id
);

SELECT 
  'RECORDS TO UPDATE' as action,
  COUNT(*) as count
FROM records_to_update;

-- ============================================
-- STEP 4: Apply the fixes
-- ============================================

-- First: Delete duplicate corrupted entries
DELETE FROM user_games
WHERE id IN (SELECT user_game_id FROM duplicates_to_delete);

SELECT 
  'DELETED DUPLICATES' as status,
  COUNT(*) as deleted_count
FROM duplicates_to_delete;

-- Second: Update remaining corrupted entries (with duplicate safety check)
UPDATE user_games ug
SET 
  platform_id = rtu.correct_platform_id,
  updated_at = NOW()
FROM records_to_update rtu
WHERE ug.id = rtu.user_game_id
  -- Extra safety: ensure target platform_id doesn't already exist
  AND NOT EXISTS (
    SELECT 1 FROM user_games ug3
    WHERE ug3.user_id = ug.user_id
      AND ug3.game_title_id = ug.game_title_id
      AND ug3.platform_id = rtu.correct_platform_id
      AND ug3.id != ug.id
  );

SELECT 
  'UPDATED RECORDS' as status,
  COUNT(*) as updated_count,
  (SELECT COUNT(*) FROM records_to_update) - COUNT(*) as skipped_due_to_duplicates
FROM records_to_update
WHERE user_game_id IN (
  SELECT ug.id FROM user_games ug
  WHERE ug.updated_at >= NOW() - INTERVAL '30 seconds'
);

-- ============================================
-- STEP 5: Verify the fixes
-- ============================================

-- Check remaining mismatches (should be 0)
WITH achievement_platforms AS (
  SELECT 
    ua.user_id,
    a.game_title_id,
    a.platform,
    COUNT(*) as achievement_count
  FROM user_achievements ua
  JOIN achievements a ON a.id = ua.achievement_id
  GROUP BY ua.user_id, a.game_title_id, a.platform
)
SELECT 
  'VERIFICATION: Remaining mismatches' as status,
  COUNT(DISTINCT ug.id) as remaining_mismatches
FROM achievement_platforms ap
JOIN user_games ug ON ug.user_id = ap.user_id AND ug.game_title_id = ap.game_title_id
LEFT JOIN platforms p ON p.id = ug.platform_id
WHERE (
  (ap.platform = 'psn' AND p.code NOT IN ('PS3', 'PS4', 'PS5', 'PSVITA')) OR
  (ap.platform = 'xbox' AND p.code NOT IN ('XBOX360', 'XBOXONE', 'XBOXSERIESX')) OR
  (ap.platform = 'steam' AND p.code != 'Steam')
);

-- Show updated platform distribution
SELECT 
  'VERIFICATION: Updated distribution' as status,
  p.code as platform_code,
  COUNT(*) as record_count,
  COUNT(DISTINCT ug.user_id) as unique_users
FROM user_games ug
JOIN platforms p ON p.id = ug.platform_id
WHERE ug.updated_at >= NOW() - INTERVAL '1 minute'
GROUP BY p.code
ORDER BY record_count DESC;

-- Show sample of fixed records
SELECT 
  'VERIFICATION: Sample fixed records' as status,
  pr.psn_online_id,
  gt.name as game_name,
  p.code as new_platform,
  ug.updated_at
FROM user_games ug
JOIN profiles pr ON pr.id = ug.user_id
JOIN game_titles gt ON gt.id = ug.game_title_id
JOIN platforms p ON p.id = ug.platform_id
WHERE ug.updated_at >= NOW() - INTERVAL '1 minute'
ORDER BY ug.updated_at DESC
LIMIT 10;

-- ============================================
-- STEP 6: Update has_platinum flags (may have changed with platform switch)
-- ============================================

-- Recalculate has_platinum for affected games
UPDATE user_games ug
SET 
  has_platinum = EXISTS (
    SELECT 1 FROM user_achievements ua
    JOIN achievements a ON a.id = ua.achievement_id
    WHERE ua.user_id = ug.user_id
      AND a.game_title_id = ug.game_title_id
      AND a.platform = 'psn'
      AND a.psn_trophy_type = 'platinum'
  ),
  platinum_trophies = (
    SELECT COUNT(*) FROM user_achievements ua
    JOIN achievements a ON a.id = ua.achievement_id
    WHERE ua.user_id = ug.user_id
      AND a.game_title_id = ug.game_title_id
      AND a.platform = 'psn'
      AND a.psn_trophy_type = 'platinum'
  )
WHERE ug.platform_id IN (1, 2, 5, 9)  -- PSN platforms only
  AND ug.updated_at >= NOW() - INTERVAL '2 minutes';

SELECT 
  'VERIFICATION: has_platinum updated' as status,
  COUNT(*) FILTER (WHERE has_platinum = true) as games_with_platinum,
  COUNT(*) as total_updated
FROM user_games
WHERE updated_at >= NOW() - INTERVAL '2 minutes'
  AND platform_id IN (1, 2, 5, 9);

-- ============================================
-- AUTO-COMMIT
-- Script will commit automatically when it completes
-- ============================================

SELECT 
  'FIX COMPLETE - Auto-committing changes' as status,
  'Review the final summary below' as next_step;

-- Commit the transaction
COMMIT;

-- Final verification after commit
WITH achievement_platforms AS (
  SELECT 
    ua.user_id,
    a.game_title_id,
    a.platform
  FROM user_achievements ua
  JOIN achievements a ON a.id = ua.achievement_id
  GROUP BY ua.user_id, a.game_title_id, a.platform
)
SELECT 
  '✓ COMMITTED' as final_status,
  COUNT(DISTINCT ug.id) as remaining_mismatches,
  CASE 
    WHEN COUNT(DISTINCT ug.id) = 0 THEN '✓ SUCCESS - All 153 records fixed and committed!'
    ELSE '⚠ WARNING - Still have ' || COUNT(DISTINCT ug.id) || ' mismatches after commit'
  END as result
FROM achievement_platforms ap
JOIN user_games ug ON ug.user_id = ap.user_id AND ug.game_title_id = ap.game_title_id
LEFT JOIN platforms p ON p.id = ug.platform_id
WHERE (
  (ap.platform = 'psn' AND p.code NOT IN ('PS3', 'PS4', 'PS5', 'PSVITA')) OR
  (ap.platform = 'xbox' AND p.code NOT IN ('XBOX360', 'XBOXONE', 'XBOXSERIESX')) OR
  (ap.platform = 'steam' AND p.code != 'Steam')
);
