-- Complete audit of Dexmorgan6981's stats BEFORE re-sync
-- User ID: 84b60ad6-cb2c-484f-8953-bf814551fd7a

-- ============================================================================
-- PROFILE INFO
-- ============================================================================
SELECT 
  'Profile Info' as section,
  display_name,
  psn_online_id,
  psn_account_id,
  xbox_gamertag,
  xbox_xuid,
  steam_id,
  steam_display_name,
  show_on_leaderboard,
  created_at
FROM profiles 
WHERE id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- ============================================================================
-- PSN STATS
-- ============================================================================
SELECT 
  'PSN Summary' as section,
  COUNT(DISTINCT ug.game_title_id) as total_games,
  SUM(ug.earned_trophies) as total_trophies_earned,
  SUM(ug.total_trophies) as total_trophies_available,
  SUM(ug.platinum_trophies) as platinums,
  SUM(ug.gold_trophies) as golds,
  SUM(ug.silver_trophies) as silvers,
  SUM(ug.bronze_trophies) as bronzes,
  ROUND(AVG(ug.completion_percent), 2) as avg_completion
FROM user_games ug
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND ug.platform_id IN (1, 2, 5, 9);

-- PSN Achievements in database
SELECT 
  'PSN Achievements in DB' as section,
  COUNT(*) as total_achievements_stored,
  COUNT(*) FILTER (WHERE a.is_platinum = true) as platinums_stored
FROM user_achievements ua
INNER JOIN achievements a ON a.id = ua.achievement_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND a.platform = 'psn';

-- ============================================================================
-- XBOX STATS
-- ============================================================================
SELECT 
  'Xbox Summary' as section,
  COUNT(DISTINCT ug.game_title_id) as total_games,
  SUM(ug.xbox_achievements_earned) as achievements_earned,
  SUM(ug.xbox_total_achievements) as achievements_available,
  SUM(ug.xbox_current_gamerscore) as current_gamerscore,
  SUM(ug.xbox_max_gamerscore) as max_gamerscore,
  ROUND(AVG(ug.completion_percent), 2) as avg_completion
FROM user_games ug
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND ug.platform_id IN (3, 10, 11, 12);

-- Xbox Achievements in database
SELECT 
  'Xbox Achievements in DB' as section,
  COUNT(*) as total_achievements_stored
FROM user_achievements ua
INNER JOIN achievements a ON a.id = ua.achievement_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND a.platform = 'xbox';

-- ============================================================================
-- STEAM STATS
-- ============================================================================
SELECT 
  'Steam Summary' as section,
  COUNT(DISTINCT ug.game_title_id) as total_games,
  SUM(ug.earned_trophies) as achievements_earned,
  SUM(ug.total_trophies) as achievements_available,
  ROUND(AVG(ug.completion_percent), 2) as avg_completion
FROM user_games ug
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND ug.platform_id = 4;

-- Steam Achievements in database
SELECT 
  'Steam Achievements in DB' as section,
  COUNT(*) as total_achievements_stored
FROM user_achievements ua
INNER JOIN achievements a ON a.id = ua.achievement_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND a.platform = 'steam';

-- ============================================================================
-- OVERALL ACHIEVEMENT STORAGE
-- ============================================================================
SELECT 
  'All Platforms - user_achievements' as section,
  COUNT(*) FILTER (WHERE a.platform = 'psn') as psn_count,
  COUNT(*) FILTER (WHERE a.platform = 'xbox') as xbox_count,
  COUNT(*) FILTER (WHERE a.platform = 'steam') as steam_count,
  COUNT(*) as total_stored
FROM user_achievements ua
INNER JOIN achievements a ON a.id = ua.achievement_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- ============================================================================
-- LEADERBOARD CACHE STATUS
-- ============================================================================
SELECT 'PSN Leaderboard Cache' as section, * 
FROM psn_leaderboard_cache 
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

SELECT 'Xbox Leaderboard Cache' as section, * 
FROM xbox_leaderboard_cache 
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

SELECT 'Steam Leaderboard Cache' as section, * 
FROM steam_leaderboard_cache 
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- ============================================================================
-- SYNC STATUS
-- ============================================================================
SELECT 
  'Current Sync Status' as section,
  last_psn_sync_at,
  psn_sync_progress,
  psn_sync_status,
  last_xbox_sync_at,
  xbox_sync_progress,
  xbox_sync_status,
  last_steam_sync_at,
  steam_sync_progress,
  steam_sync_status
FROM profiles
WHERE id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';
