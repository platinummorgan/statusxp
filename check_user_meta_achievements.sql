-- Check if user has meta achievements unlocked
-- Replace with your actual user ID

SELECT 
  uma.achievement_id,
  uma.unlocked_at
FROM user_meta_achievements uma
WHERE uma.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
ORDER BY uma.unlocked_at DESC;

-- Count total
SELECT COUNT(*) as total_unlocked
FROM user_meta_achievements
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';
