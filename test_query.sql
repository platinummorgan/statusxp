-- Test the exact query the app is running
SELECT 
  ua.achievement_id, 
  ua.earned_at, 
  a.game_title_id
FROM user_achievements ua
JOIN achievements a ON a.id = ua.achievement_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND ua.earned_at IS NOT NULL
ORDER BY ua.earned_at DESC
LIMIT 5;

-- Check if the inner join syntax works
SELECT COUNT(*) as total
FROM user_achievements
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND earned_at IS NOT NULL;
