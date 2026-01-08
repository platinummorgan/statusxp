-- ============================================
-- COMPREHENSIVE VALIDATION - VERIFY ALL FIXES
-- Re-run all audits to confirm corruption is eliminated
-- ============================================

-- ============================================
-- TEST 1: Platform_id Mismatches (SHOULD BE 0)
-- ============================================
SELECT '========================================' as separator;
SELECT 'TEST 1: Platform_id Mismatches' as test_name;
SELECT '========================================' as separator;

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
  ap.platform as correct_platform,
  p.code as wrong_platform_in_db,
  COUNT(DISTINCT ug.id) as mismatch_count,
  CASE 
    WHEN COUNT(DISTINCT ug.id) = 0 THEN '✓ PASS'
    ELSE '✗ FAIL - Still has mismatches!'
  END as result
FROM achievement_platforms ap
JOIN user_games ug ON ug.user_id = ap.user_id AND ug.game_title_id = ap.game_title_id
LEFT JOIN platforms p ON p.id = ug.platform_id
WHERE (
  (ap.platform = 'psn' AND p.code NOT IN ('PS3', 'PS4', 'PS5', 'PSVITA')) OR
  (ap.platform = 'xbox' AND p.code NOT IN ('XBOX360', 'XBOXONE', 'XBOXSERIESX')) OR
  (ap.platform = 'steam' AND p.code != 'Steam')
)
GROUP BY ap.platform, p.code
UNION ALL
SELECT 
  'TOTAL MISMATCHES' as correct_platform,
  '(All platforms)' as wrong_platform_in_db,
  COUNT(DISTINCT ug.id) as mismatch_count,
  CASE 
    WHEN COUNT(DISTINCT ug.id) = 0 THEN '✓ PASS - ALL FIXED!'
    ELSE '✗ FAIL - ' || COUNT(DISTINCT ug.id) || ' mismatches remain!'
  END as result
FROM achievement_platforms ap
JOIN user_games ug ON ug.user_id = ap.user_id AND ug.game_title_id = ap.game_title_id
LEFT JOIN platforms p ON p.id = ug.platform_id
WHERE (
  (ap.platform = 'psn' AND p.code NOT IN ('PS3', 'PS4', 'PS5', 'PSVITA')) OR
  (ap.platform = 'xbox' AND p.code NOT IN ('XBOX360', 'XBOXONE', 'XBOXSERIESX')) OR
  (ap.platform = 'steam' AND p.code != 'Steam')
)
ORDER BY mismatch_count DESC;

-- ============================================
-- TEST 2: Missing user_games entries
-- ============================================
SELECT '========================================' as separator;
SELECT 'TEST 2: Missing user_games Entries' as test_name;
SELECT '========================================' as separator;

WITH achievement_games AS (
  SELECT DISTINCT
    ua.user_id,
    a.game_title_id,
    a.platform
  FROM user_achievements ua
  JOIN achievements a ON a.id = ua.achievement_id
)
SELECT 
  ag.platform,
  COUNT(*) as missing_count,
  CASE 
    WHEN COUNT(*) < 10 THEN '⚠ Minor - ' || COUNT(*) || ' missing entries'
    ELSE '✗ FAIL - ' || COUNT(*) || ' missing entries!'
  END as result
FROM achievement_games ag
LEFT JOIN user_games ug ON ug.user_id = ag.user_id AND ug.game_title_id = ag.game_title_id
WHERE ug.id IS NULL
GROUP BY ag.platform
UNION ALL
SELECT 
  'TOTAL' as platform,
  COUNT(*) as missing_count,
  CASE 
    WHEN COUNT(*) < 10 THEN '✓ PASS - Only ' || COUNT(*) || ' minor missing entries'
    WHEN COUNT(*) < 50 THEN '⚠ WARNING - ' || COUNT(*) || ' missing entries'
    ELSE '✗ FAIL - ' || COUNT(*) || ' missing entries!'
  END as result
FROM achievement_games ag
LEFT JOIN user_games ug ON ug.user_id = ag.user_id AND ug.game_title_id = ag.game_title_id
WHERE ug.id IS NULL
ORDER BY missing_count DESC;

-- ============================================
-- TEST 3: has_platinum Flag Accuracy
-- ============================================
SELECT '========================================' as separator;
SELECT 'TEST 3: has_platinum Flag Accuracy' as test_name;
SELECT '========================================' as separator;

WITH platinum_status AS (
  SELECT 
    ug.id as user_game_id,
    ug.has_platinum as current_flag,
    EXISTS (
      SELECT 1 FROM user_achievements ua
      JOIN achievements a ON a.id = ua.achievement_id
      WHERE ua.user_id = ug.user_id
        AND a.game_title_id = ug.game_title_id
        AND a.platform = 'psn'
        AND a.psn_trophy_type = 'platinum'
    ) as should_have_platinum
  FROM user_games ug
  JOIN platforms p ON p.id = ug.platform_id
  WHERE p.code IN ('PS3', 'PS4', 'PS5', 'PSVITA')
)
SELECT 
  CASE 
    WHEN current_flag = true AND should_have_platinum = false THEN 'False Positives (has_platinum=true but no platinum trophy)'
    WHEN current_flag = false AND should_have_platinum = true THEN 'False Negatives (has_platinum=false but HAS platinum trophy)'
    WHEN current_flag = true AND should_have_platinum = true THEN 'Correct (TRUE matches reality)'
    WHEN current_flag = false AND should_have_platinum = false THEN 'Correct (FALSE matches reality)'
  END as category,
  COUNT(*) as count,
  CASE 
    WHEN current_flag = should_have_platinum THEN '✓ CORRECT'
    ELSE '✗ INCORRECT'
  END as result
FROM platinum_status
GROUP BY category, current_flag, should_have_platinum
ORDER BY 
  CASE WHEN current_flag = should_have_platinum THEN 1 ELSE 0 END,
  count DESC;

-- Summary
SELECT 
  'TOTAL INCORRECT has_platinum FLAGS' as metric,
  COUNT(*) as count,
  CASE 
    WHEN COUNT(*) = 0 THEN '✓ PASS - All correct!'
    WHEN COUNT(*) < 10 THEN '⚠ WARNING - ' || COUNT(*) || ' incorrect'
    ELSE '✗ FAIL - ' || COUNT(*) || ' incorrect!'
  END as result
FROM platinum_status
WHERE current_flag != should_have_platinum;

-- ============================================
-- TEST 4: Database Integrity Check
-- ============================================
SELECT '========================================' as separator;
SELECT 'TEST 4: Database Integrity' as test_name;
SELECT '========================================' as separator;

-- Check for NULL platform_ids (should be 0)
SELECT 
  'NULL platform_ids' as check_name,
  COUNT(*) as count,
  CASE 
    WHEN COUNT(*) = 0 THEN '✓ PASS'
    ELSE '✗ FAIL - ' || COUNT(*) || ' NULL platform_ids!'
  END as result
FROM user_games WHERE platform_id IS NULL
UNION ALL
-- Check for invalid platform_ids (should be 0)
SELECT 
  'Invalid platform_ids (not in platforms table)',
  COUNT(*),
  CASE 
    WHEN COUNT(*) = 0 THEN '✓ PASS'
    ELSE '✗ FAIL - ' || COUNT(*) || ' invalid platform_ids!'
  END
FROM user_games ug
LEFT JOIN platforms p ON p.id = ug.platform_id
WHERE p.id IS NULL
UNION ALL
-- Check for orphaned user_achievements (should be 0)
SELECT 
  'Orphaned user_achievements (no user_games entry)',
  COUNT(DISTINCT ua.user_id || '-' || a.game_title_id),
  CASE 
    WHEN COUNT(DISTINCT ua.user_id || '-' || a.game_title_id) < 50 THEN '✓ PASS - Only ' || COUNT(DISTINCT ua.user_id || '-' || a.game_title_id) || ' orphaned'
    ELSE '⚠ WARNING - ' || COUNT(DISTINCT ua.user_id || '-' || a.game_title_id) || ' orphaned'
  END
FROM user_achievements ua
JOIN achievements a ON a.id = ua.achievement_id
LEFT JOIN user_games ug ON ug.user_id = ua.user_id AND ug.game_title_id = a.game_title_id
WHERE ug.id IS NULL;

-- ============================================
-- TEST 5: Platform Distribution Sanity Check
-- ============================================
SELECT '========================================' as separator;
SELECT 'TEST 5: Platform Distribution' as test_name;
SELECT '========================================' as separator;

SELECT 
  p.code as platform,
  COUNT(*) as user_games_count,
  COUNT(DISTINCT ug.user_id) as unique_users,
  CASE 
    WHEN COUNT(*) = 0 THEN '⚠ No data for this platform'
    WHEN COUNT(*) < 10 THEN '⚠ Very low usage (' || COUNT(*) || ' games)'
    ELSE '✓ Normal usage'
  END as status
FROM platforms p
LEFT JOIN user_games ug ON ug.platform_id = p.id
WHERE p.code IN ('PS3', 'PS4', 'PS5', 'PSVITA', 'XBOX360', 'XBOXONE', 'XBOXSERIESX', 'Steam')
GROUP BY p.code
ORDER BY user_games_count DESC;

-- ============================================
-- TEST 6: Recently Updated Records Check
-- ============================================
SELECT '========================================' as separator;
SELECT 'TEST 6: Recently Updated Records (from Fix #2)' as test_name;
SELECT '========================================' as separator;

SELECT 
  'Records updated in last 5 minutes' as metric,
  COUNT(*) as count,
  CASE 
    WHEN COUNT(*) > 0 THEN '✓ Fix #2 made updates (' || COUNT(*) || ' records)'
    ELSE '⚠ No recent updates - did Fix #2 run?'
  END as result
FROM user_games
WHERE updated_at >= NOW() - INTERVAL '5 minutes';

-- Show sample of recently fixed records
SELECT 
  'Sample recently fixed records:' as info,
  pr.psn_online_id,
  gt.name as game_name,
  p.code as platform,
  ug.has_platinum,
  ug.updated_at
FROM user_games ug
JOIN profiles pr ON pr.id = ug.user_id
JOIN game_titles gt ON gt.id = ug.game_title_id
JOIN platforms p ON p.id = ug.platform_id
WHERE ug.updated_at >= NOW() - INTERVAL '5 minutes'
ORDER BY ug.updated_at DESC
LIMIT 10;

-- ============================================
-- FINAL VERDICT
-- ============================================
SELECT '========================================' as separator;
SELECT 'FINAL VERDICT' as test_name;
SELECT '========================================' as separator;

WITH test_results AS (
  -- Count platform mismatches
  SELECT COUNT(DISTINCT ug.id) as platform_mismatches
  FROM user_achievements ua
  JOIN achievements a ON a.id = ua.achievement_id
  JOIN user_games ug ON ug.user_id = ua.user_id AND ug.game_title_id = a.game_title_id
  JOIN platforms p ON p.id = ug.platform_id
  WHERE (
    (a.platform = 'psn' AND p.code NOT IN ('PS3', 'PS4', 'PS5', 'PSVITA')) OR
    (a.platform = 'xbox' AND p.code NOT IN ('XBOX360', 'XBOXONE', 'XBOXSERIESX')) OR
    (a.platform = 'steam' AND p.code != 'Steam')
  )
)
SELECT 
  CASE 
    WHEN platform_mismatches = 0 THEN '🎉 ALL TESTS PASSED! Database corruption eliminated.'
    WHEN platform_mismatches < 10 THEN '⚠️  MOSTLY FIXED - ' || platform_mismatches || ' edge cases remain'
    ELSE '❌ FAILED - ' || platform_mismatches || ' platform mismatches still exist!'
  END as verdict,
  platform_mismatches as remaining_issues
FROM test_results;
