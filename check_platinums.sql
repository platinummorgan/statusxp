-- Simple count of platinums in user_achievements
SELECT COUNT(*) as platinum_count_new_table
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND a.platform = 'psn'
  AND a.psn_trophy_type = 'platinum';

-- Check if user_trophies table exists and has platinums
SELECT COUNT(*) as platinum_count_old_table
FROM user_trophies ut
JOIN trophies t ON ut.trophy_id = t.id
WHERE ut.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND t.trophy_type = 'platinum';
