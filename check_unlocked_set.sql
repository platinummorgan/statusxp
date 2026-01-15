-- Check what _getUnlockedAchievementIds should return
-- This simulates the Dart query

SELECT achievement_id
FROM user_meta_achievements
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
ORDER BY achievement_id;

-- Count - should be 74
SELECT COUNT(*) as count
FROM user_meta_achievements
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';
