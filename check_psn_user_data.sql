-- Check which table PSN user data is in
SELECT 'user_achievements' as table_name, COUNT(*) as count
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND a.platform = 'psn'

UNION ALL

SELECT 'user_trophies' as table_name, COUNT(*) as count
FROM user_trophies ut
JOIN trophies t ON ut.trophy_id = t.id
WHERE ut.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';
