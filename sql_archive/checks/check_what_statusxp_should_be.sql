-- ============================================================================
-- Check what StatusXP SHOULD be
-- ============================================================================

-- Your actual StatusXP from achievements
SELECT 
  'Direct calculation from achievements' as source,
  SUM(a.base_status_xp * COALESCE(a.rarity_multiplier::numeric, 1.0))::bigint as total_statusxp,
  COUNT(DISTINCT CONCAT(ua.platform_id, '-', ua.platform_game_id)) as game_count
FROM user_achievements ua
INNER JOIN achievements a ON a.platform_id = ua.platform_id
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- What's currently in leaderboard_cache
SELECT 
  'Current leaderboard_cache' as source,
  total_statusxp,
  total_game_entries as game_count
FROM leaderboard_cache
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Check if there's a view or function being used
SELECT 
  proname as function_name
FROM pg_proc
WHERE proname LIKE '%statusxp%' OR proname LIKE '%leaderboard%'
ORDER BY proname;
