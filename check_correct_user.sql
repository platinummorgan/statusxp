-- Check achievement data for correct user
SELECT 
  COUNT(*) as total_earned_achievements,
  COUNT(CASE WHEN earned_at IS NOT NULL THEN 1 END) as with_timestamps,
  MIN(earned_at) as earliest_achievement,
  MAX(earned_at) as latest_achievement
FROM user_achievements
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Sample of recent achievements
SELECT 
  ua.earned_at,
  gt.name as game_name,
  a.name as achievement_name
FROM user_achievements ua
JOIN achievements a ON a.id = ua.achievement_id
JOIN game_titles gt ON gt.id = a.game_title_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND ua.earned_at IS NOT NULL
ORDER BY ua.earned_at DESC
LIMIT 10;
