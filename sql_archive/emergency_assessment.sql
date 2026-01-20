-- EMERGENCY DATABASE ASSESSMENT
-- Run this to understand the current state

-- ============================================
-- 1. CHECK V2 TABLES - DO THEY HAVE REAL DATA?
-- ============================================

SELECT 'games_v2' as table_name, COUNT(*) as row_count FROM games_v2
UNION ALL
SELECT 'achievements_v2', COUNT(*) FROM achievements_v2
UNION ALL
SELECT 'user_achievements_v2', COUNT(*) FROM user_achievements_v2
UNION ALL
SELECT 'user_progress_v2', COUNT(*) FROM user_progress_v2;

-- ============================================
-- 2. CHECK ORIGINAL TABLES STATUS
-- ============================================

SELECT 
  'Original Tables' as section,
  (SELECT COUNT(*) FROM profiles WHERE merged_into_user_id IS NULL) as active_users,
  (SELECT COUNT(*) FROM game_titles) as game_titles,
  (SELECT COUNT(*) FROM achievements) as achievements,
  (SELECT COUNT(*) FROM user_achievements) as user_achievements,
  (SELECT COUNT(*) FROM user_games) as user_games;

-- ============================================
-- 3. CHECK STATUSXP CALCULATION STATUS
-- ============================================

-- Check if statusxp columns exist and have values
SELECT 
  'StatusXP Check' as section,
  COUNT(*) as total_user_achievements,
  COUNT(statusxp_points) as has_statusxp_column,
  SUM(CASE WHEN statusxp_points > 0 THEN 1 ELSE 0 END) as has_statusxp_value,
  SUM(CASE WHEN statusxp_points IS NULL OR statusxp_points = 0 THEN 1 ELSE 0 END) as missing_statusxp
FROM user_achievements;

-- Check user_games statusxp
SELECT 
  'User Games StatusXP' as section,
  COUNT(*) as total_user_games,
  SUM(CASE WHEN statusxp_raw > 0 THEN 1 ELSE 0 END) as has_raw_statusxp,
  SUM(CASE WHEN statusxp_effective > 0 THEN 1 ELSE 0 END) as has_effective_statusxp,
  SUM(CASE WHEN statusxp_raw IS NULL OR statusxp_raw = 0 THEN 1 ELSE 0 END) as missing_statusxp
FROM user_games;

-- ============================================
-- 4. CHECK SYNC STATUS
-- ============================================

SELECT 
  psn_sync_status,
  COUNT(*) as user_count
FROM profiles
WHERE merged_into_user_id IS NULL
GROUP BY psn_sync_status
ORDER BY user_count DESC;

SELECT 
  xbox_sync_status,
  COUNT(*) as user_count
FROM profiles
WHERE merged_into_user_id IS NULL AND xbox_gamertag IS NOT NULL
GROUP BY xbox_sync_status
ORDER BY user_count DESC;

SELECT 
  steam_sync_status,
  COUNT(*) as user_count
FROM profiles
WHERE merged_into_user_id IS NULL AND steam_id IS NOT NULL
GROUP BY steam_sync_status
ORDER BY user_count DESC;

-- ============================================
-- 5. CHECK FOR BROKEN CONSTRAINTS
-- ============================================

SELECT 
  conname as constraint_name,
  contype as constraint_type,
  pg_get_constraintdef(oid) as definition
FROM pg_constraint
WHERE conrelid = 'achievements_v2'::regclass
  OR conrelid = 'user_achievements_v2'::regclass
  OR conrelid = 'user_progress_v2'::regclass
  OR conrelid = 'games_v2'::regclass
ORDER BY conrelid::regclass::text, conname;

-- ============================================
-- 6. CHECK FOR TRIGGERS THAT MIGHT BE BROKEN
-- ============================================

SELECT 
  schemaname,
  tablename,
  trigger_name,
  event_manipulation,
  action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND (tablename LIKE '%achievement%' 
    OR tablename LIKE '%user_games%'
    OR tablename = 'profiles')
ORDER BY tablename, trigger_name;

-- ============================================
-- 7. CHECK FUNCTIONS RELATED TO STATUSXP
-- ============================================

SELECT 
  routine_name,
  routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND (routine_name LIKE '%statusxp%'
    OR routine_name LIKE '%calculate%'
    OR routine_name LIKE '%update_user_games%')
ORDER BY routine_name;

-- ============================================
-- 8. SAMPLE OF AFFECTED USER DATA
-- ============================================

-- Get a few users to see the damage
SELECT 
  p.id,
  p.username,
  p.psn_sync_status,
  p.xbox_sync_status,
  p.steam_sync_status,
  COUNT(DISTINCT ug.id) as game_count,
  COUNT(DISTINCT ua.id) as achievement_count,
  SUM(ug.statusxp_effective) as total_statusxp
FROM profiles p
LEFT JOIN user_games ug ON ug.user_id = p.id
LEFT JOIN user_achievements ua ON ua.user_id = p.id
WHERE p.merged_into_user_id IS NULL
GROUP BY p.id, p.username, p.psn_sync_status, p.xbox_sync_status, p.steam_sync_status
ORDER BY achievement_count DESC
LIMIT 10;
