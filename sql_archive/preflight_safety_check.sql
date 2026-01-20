-- ============================================
-- PRE-FLIGHT SAFETY CHECK
-- Run this BEFORE making any code fixes
-- Verifies assumptions about database state
-- ============================================

-- CHECK 1: What is the ACTUAL unique constraint on user_games?
SELECT 
  'CHECK_1: user_games constraints' as check_name,
  conname as constraint_name,
  pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint
WHERE conrelid = 'user_games'::regclass
  AND contype = 'u';  -- unique constraints

-- CHECK 2: Does platform_id column exist?
SELECT 
  'CHECK_2: platform_id column existence' as check_name,
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_name = 'user_games'
  AND column_name = 'platform_id';

-- CHECK 3: What platforms exist in database?
SELECT 
  'CHECK_3: Available platforms' as check_name,
  id,
  code,
  name
FROM platforms
ORDER BY id;

-- CHECK 4: Current platform_id distribution in user_games
SELECT 
  'CHECK_4: Current platform_id distribution' as check_name,
  ug.platform_id,
  p.code as platform_code,
  p.name as platform_name,
  COUNT(*) as record_count,
  COUNT(DISTINCT ug.user_id) as unique_users
FROM user_games ug
LEFT JOIN platforms p ON p.id = ug.platform_id
GROUP BY ug.platform_id, p.code, p.name
ORDER BY ug.platform_id;

-- CHECK 5: NULL or invalid platform_ids
SELECT 
  'CHECK_5: NULL or orphaned platform_ids' as check_name,
  COUNT(*) FILTER (WHERE ug.platform_id IS NULL) as null_platform_ids,
  COUNT(*) FILTER (WHERE ug.platform_id IS NOT NULL AND p.id IS NULL) as orphaned_platform_ids,
  COUNT(*) as total_user_games
FROM user_games ug
LEFT JOIN platforms p ON p.id = ug.platform_id;

-- CHECK 6: Games with achievements but wrong platform_id (the core bug)
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
  'CHECK_6: Platform mismatches by platform' as check_name,
  ap.platform as achievement_platform,
  p.code as stored_platform_code,
  COUNT(DISTINCT ug.user_id || '-' || ug.game_title_id) as mismatched_games
FROM achievement_platforms ap
JOIN user_games ug ON ug.user_id = ap.user_id AND ug.game_title_id = ap.game_title_id
LEFT JOIN platforms p ON p.id = ug.platform_id
WHERE (
  (ap.platform = 'psn' AND p.code NOT IN ('PS3', 'PS4', 'PS5', 'PSVITA')) OR
  (ap.platform = 'xbox' AND p.code NOT IN ('XBOX360', 'XBOXONE', 'XBOXSERIESX')) OR
  (ap.platform = 'steam' AND p.code != 'Steam')
)
GROUP BY ap.platform, p.code
ORDER BY ap.platform, mismatched_games DESC;

-- CHECK 7: Multi-platform game ownership (users with same game on multiple platforms)
SELECT 
  'CHECK_7: Multi-platform ownership cases' as check_name,
  COUNT(DISTINCT ua.user_id || '-' || a.game_title_id) as affected_user_games,
  COUNT(DISTINCT ua.user_id) as affected_users
FROM user_achievements ua
JOIN achievements a ON a.id = ua.achievement_id
WHERE EXISTS (
  SELECT 1 FROM user_achievements ua2
  JOIN achievements a2 ON a2.id = ua2.achievement_id
  WHERE ua2.user_id = ua.user_id
    AND a2.game_title_id = a.game_title_id
    AND a2.platform != a.platform
);

-- CHECK 8: What happens if we simulate the upsert with wrong conflict clause?
-- This checks if specifying a non-existent conflict clause causes issues
-- (Just reporting, not executing)
SELECT 
  'CHECK_8: Upsert conflict clause validation' as check_name,
  'Current sync services use: onConflict: user_id,game_title_id,platform_id' as code_behavior,
  'Actual constraint is: ' || string_agg(pg_get_constraintdef(oid), '; ') as database_constraint,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM pg_constraint 
      WHERE conrelid = 'user_games'::regclass 
        AND contype = 'u'
        AND pg_get_constraintdef(oid) LIKE '%user_id%game_title_id%platform_id%'
    ) THEN '✅ MATCH - Constraint includes platform_id'
    ELSE '❌ MISMATCH - Constraint does NOT include platform_id'
  END as status
FROM pg_constraint
WHERE conrelid = 'user_games'::regclass
  AND contype = 'u';

-- CHECK 9: Verify platform lookup will work for each sync service
DO $$
DECLARE
  psn_platforms_exist BOOLEAN;
  xbox_platforms_exist BOOLEAN;
  steam_platform_exists BOOLEAN;
BEGIN
  -- Check PSN platforms
  SELECT EXISTS (
    SELECT 1 FROM platforms WHERE code IN ('PS3', 'PS4', 'PS5', 'PSVITA')
  ) INTO psn_platforms_exist;
  
  -- Check Xbox platforms
  SELECT EXISTS (
    SELECT 1 FROM platforms WHERE code IN ('XBOX360', 'XBOXONE', 'XBOXSERIESX')
  ) INTO xbox_platforms_exist;
  
  -- Check Steam platform
  SELECT EXISTS (
    SELECT 1 FROM platforms WHERE code = 'Steam'
  ) INTO steam_platform_exists;
  
  RAISE NOTICE 'CHECK_9: Platform availability';
  RAISE NOTICE '  PSN Platforms: %', CASE WHEN psn_platforms_exist THEN '✅ EXISTS' ELSE '❌ MISSING' END;
  RAISE NOTICE '  Xbox Platforms: %', CASE WHEN xbox_platforms_exist THEN '✅ EXISTS' ELSE '❌ MISSING' END;
  RAISE NOTICE '  Steam Platform: %', CASE WHEN steam_platform_exists THEN '✅ EXISTS' ELSE '❌ MISSING' END;
END $$;

-- CHECK 10: Sample of actual corrupted data
SELECT 
  'CHECK_10: Sample corrupted records' as check_name,
  p.psn_online_id,
  gt.name as game_name,
  ug.platform_id as stored_platform_id,
  pl.code as stored_platform_code,
  a.platform as achievement_platform,
  COUNT(ua.id) as achievement_count
FROM user_games ug
JOIN profiles p ON p.id = ug.user_id
JOIN game_titles gt ON gt.id = ug.game_title_id
LEFT JOIN platforms pl ON pl.id = ug.platform_id
JOIN user_achievements ua ON ua.user_id = ug.user_id
JOIN achievements a ON a.id = ua.achievement_id AND a.game_title_id = ug.game_title_id
WHERE (
  (a.platform = 'psn' AND pl.code NOT IN ('PS3', 'PS4', 'PS5', 'PSVITA')) OR
  (a.platform = 'xbox' AND pl.code NOT IN ('XBOX360', 'XBOXONE', 'XBOXSERIESX')) OR
  (a.platform = 'steam' AND pl.code != 'Steam')
)
GROUP BY p.psn_online_id, gt.name, ug.platform_id, pl.code, a.platform
LIMIT 10;

-- ============================================
-- SUMMARY
-- ============================================
SELECT 
  'SUMMARY' as report_section,
  'Review all checks above before proceeding with fixes' as message,
  'Pay special attention to CHECK_8 - if MISMATCH, upsert behavior is undefined' as critical_note;
