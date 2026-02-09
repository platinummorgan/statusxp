-- Debug the xbox_leaderboard_cache calculation
SELECT 
  ua.user_id,
  COUNT(*) as achievement_count,
  COUNT(DISTINCT a.platform_game_id) as total_games,
  SUM((up.metadata->>'current_gamerscore')::integer) as sum_metadata_gamerscore,
  SUM(ROUND((up.metadata->>'max_gamerscore')::numeric * up.completion_percentage / 100)::integer) as sum_calculated_gamerscore
FROM user_achievements ua
JOIN achievements a ON a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
LEFT JOIN user_progress up ON up.user_id = ua.user_id 
  AND up.platform_id = a.platform_id
  AND up.platform_game_id = a.platform_game_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND ua.platform_id IN (10, 11, 12)
GROUP BY ua.user_id;

-- Check raw metadata values
SELECT 
  platform_game_id,
  metadata->>'current_gamerscore' as current_gamerscore,
  metadata->>'max_gamerscore' as max_gamerscore,
  completion_percentage
FROM user_progress
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND platform_id IN (10, 11, 12)
LIMIT 5;
