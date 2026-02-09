-- Investigation for user showing 0 statusxp
-- Replace USER_NAME with the actual user's username

-- 1. Check leaderboard_cache
SELECT 
  user_id,
  total_statusxp,
  total_game_entries,
  last_updated
FROM leaderboard_cache
WHERE user_id = (SELECT id FROM profiles WHERE username = 'USER_NAME');

-- 2. Check their user_progress current_score values
SELECT 
  platform_id,
  platform_game_id,
  completion_percentage,
  achievements_earned,
  current_score,
  synced_at,
  first_played_at
FROM user_progress
WHERE user_id = (SELECT id FROM profiles WHERE username = 'USER_NAME')
ORDER BY platform_id, synced_at DESC;

-- 3. Check if they have any achievements
SELECT 
  COUNT(*) as total_achievements,
  SUM(CASE WHEN a.base_status_xp IS NOT NULL THEN a.base_status_xp ELSE 0 END) as total_raw_statusxp
FROM user_achievements ua
JOIN achievements a ON 
  a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = (SELECT id FROM profiles WHERE username = 'USER_NAME');

-- 4. Run calculate_statusxp_with_stacks to see what SHOULD be calculated
SELECT *
FROM calculate_statusxp_with_stacks((SELECT id FROM profiles WHERE username = 'USER_NAME'));
