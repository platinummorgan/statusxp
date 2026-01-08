-- COMPREHENSIVE DATABASE AUDIT FOR STATUSXP
-- Checks data integrity across all users and platforms

-- ============================================
-- ISSUE 1: Orphaned has_platinum flags
-- Games with has_platinum=true but NO platinum achievement record
-- ============================================
SELECT 
  'ORPHANED_HAS_PLATINUM' as issue_type,
  p.psn_online_id,
  gt.name as game_name,
  ug.platform_id,
  ug.has_platinum,
  ug.platinum_trophies
FROM user_games ug
JOIN profiles p ON p.id = ug.user_id
JOIN game_titles gt ON gt.id = ug.game_title_id
WHERE ug.has_platinum = true
  AND ug.platform_id = 1  -- PSN only
  AND NOT EXISTS (
    SELECT 1 FROM user_achievements ua
    JOIN achievements a ON a.id = ua.achievement_id
    WHERE ua.user_id = ug.user_id
      AND a.game_title_id = ug.game_title_id
      AND a.psn_trophy_type = 'platinum'
      AND a.platform = 'psn'
  )
ORDER BY p.psn_online_id, gt.name;

-- ============================================
-- ISSUE 2: Missing has_platinum flags
-- User has platinum achievement but has_platinum=false
-- ============================================
SELECT 
  'MISSING_HAS_PLATINUM' as issue_type,
  p.psn_online_id,
  gt.name as game_name,
  ug.has_platinum,
  ug.platinum_trophies
FROM user_achievements ua
JOIN achievements a ON a.id = ua.achievement_id
JOIN game_titles gt ON gt.id = a.game_title_id
JOIN profiles p ON p.id = ua.user_id
LEFT JOIN user_games ug ON ug.user_id = ua.user_id 
  AND ug.game_title_id = a.game_title_id 
  AND ug.platform_id = 1
WHERE a.psn_trophy_type = 'platinum'
  AND a.platform = 'psn'
  AND (ug.has_platinum = false OR ug.has_platinum IS NULL)
ORDER BY p.psn_online_id, gt.name;

-- ============================================
-- ISSUE 3: Platform mismatches
-- PSN achievements linked to Xbox/Steam games
-- ============================================
SELECT 
  'PLATFORM_MISMATCH' as issue_type,
  p.psn_online_id,
  gt.name as game_name,
  ug.platform_id,
  CASE ug.platform_id 
    WHEN 1 THEN 'PSN'
    WHEN 2 THEN 'Xbox'
    WHEN 3 THEN 'Steam'
  END as stored_platform,
  COUNT(*) as psn_achievements_count
FROM user_achievements ua
JOIN achievements a ON a.id = ua.achievement_id
JOIN game_titles gt ON gt.id = a.game_title_id
JOIN profiles p ON p.id = ua.user_id
JOIN user_games ug ON ug.user_id = ua.user_id 
  AND ug.game_title_id = a.game_title_id
WHERE a.platform = 'psn'
  AND ug.platform_id != 1  -- Should be PSN but isn't
GROUP BY p.psn_online_id, gt.name, ug.platform_id
ORDER BY p.psn_online_id, gt.name;

-- ============================================
-- ISSUE 4: Leaderboard cache mismatches
-- Cache shows different platinum count than actual achievements
-- ============================================
WITH actual_counts AS (
  SELECT 
    p.id as user_id,
    p.psn_online_id,
    COUNT(DISTINCT CASE WHEN a.psn_trophy_type = 'platinum' THEN ua.id END) as actual_platinum_count
  FROM profiles p
  LEFT JOIN user_achievements ua ON ua.user_id = p.id
  LEFT JOIN achievements a ON a.id = ua.achievement_id AND a.platform = 'psn'
  WHERE p.psn_account_id IS NOT NULL
  GROUP BY p.id, p.psn_online_id
)
SELECT 
  'LEADERBOARD_CACHE_MISMATCH' as issue_type,
  ac.psn_online_id,
  ac.actual_platinum_count,
  COALESCE(lc.platinum_count, 0) as cached_platinum_count,
  (ac.actual_platinum_count - COALESCE(lc.platinum_count, 0)) as difference
FROM actual_counts ac
LEFT JOIN psn_leaderboard_cache lc ON lc.user_id = ac.user_id
WHERE ac.actual_platinum_count != COALESCE(lc.platinum_count, 0)
ORDER BY ABS(ac.actual_platinum_count - COALESCE(lc.platinum_count, 0)) DESC;

-- ============================================
-- ISSUE 5: Duplicate user_games entries
-- Same user + game + platform appearing multiple times
-- ============================================
SELECT 
  'DUPLICATE_USER_GAMES' as issue_type,
  p.psn_online_id,
  gt.name as game_name,
  ug.platform_id,
  COUNT(*) as duplicate_count
FROM user_games ug
JOIN profiles p ON p.id = ug.user_id
JOIN game_titles gt ON gt.id = ug.game_title_id
GROUP BY p.psn_online_id, gt.name, ug.platform_id, p.id, gt.id
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- ============================================
-- ISSUE 6: Achievement records without corresponding user_games
-- User has achievements for a game but no user_games entry
-- ============================================
SELECT 
  'ACHIEVEMENTS_WITHOUT_USER_GAME' as issue_type,
  p.psn_online_id,
  gt.name as game_name,
  COUNT(*) as achievement_count
FROM user_achievements ua
JOIN achievements a ON a.id = ua.achievement_id
JOIN game_titles gt ON gt.id = a.game_title_id
JOIN profiles p ON p.id = ua.user_id
WHERE a.platform = 'psn'
  AND NOT EXISTS (
    SELECT 1 FROM user_games ug
    WHERE ug.user_id = ua.user_id
      AND ug.game_title_id = a.game_title_id
      AND ug.platform_id = 1
  )
GROUP BY p.psn_online_id, gt.name, p.id, gt.id
ORDER BY achievement_count DESC;

-- ============================================
-- ISSUE 7: Games with 100% completion but no platinum
-- (Some games don't have platinums, so this is FYI only)
-- ============================================
SELECT 
  'COMPLETED_WITHOUT_PLATINUM' as issue_type,
  p.psn_online_id,
  gt.name as game_name,
  ug.completion_percent,
  ug.has_platinum,
  ug.total_trophies
FROM user_games ug
JOIN profiles p ON p.id = ug.user_id
JOIN game_titles gt ON gt.id = ug.game_title_id
WHERE ug.platform_id = 1
  AND ug.completion_percent >= 100
  AND ug.has_platinum = false
  AND ug.total_trophies > 10  -- Filter out tiny DLC packs
ORDER BY p.psn_online_id, ug.total_trophies DESC;

-- ============================================
-- SUMMARY: Count of each issue type
-- ============================================
SELECT 'AUDIT_SUMMARY' as report_type, 
       'Review the queries above to see detailed issues' as message;
