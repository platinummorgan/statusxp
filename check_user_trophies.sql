-- Check if we have user_achievements data with earned_at timestamps
SELECT 
  COUNT(*) as total_earned_achievements,
  COUNT(CASE WHEN earned_at IS NOT NULL THEN 1 END) as with_timestamps,
  MIN(earned_at) as earliest_achievement,
  MAX(earned_at) as latest_achievement
FROM user_achievements
WHERE user_id = 'b597a65e-2397-4b71-a3de-9c0b67ec1bf8';

-- Sample of recent achievements with game info
SELECT 
  ua.earned_at,
  gt.name as game_name,
  a.name as achievement_name
FROM user_achievements ua
JOIN achievements a ON a.id = ua.achievement_id
JOIN game_titles gt ON gt.id = a.game_title_id
WHERE ua.user_id = 'b597a65e-2397-4b71-a3de-9c0b67ec1bf8'
  AND ua.earned_at IS NOT NULL
ORDER BY ua.earned_at DESC
LIMIT 10;
