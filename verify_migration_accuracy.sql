-- Check for duplicate trophies in user_achievements
SELECT 
  user_id,
  achievement_id,
  COUNT(*) as duplicate_count
FROM user_achievements
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
GROUP BY user_id, achievement_id
HAVING COUNT(*) > 1;

-- Check actual platinum count in user_trophies (old table)
SELECT COUNT(*) as platinum_count_old_table
FROM user_trophies ut
JOIN trophies t ON ut.trophy_id = t.id
WHERE ut.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND t.psn_trophy_type = 'platinum';

-- Check total trophy count in old table
SELECT COUNT(*) as total_trophies_old_table
FROM user_trophies
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Breakdown by platform in new table
SELECT 
  a.platform,
  COUNT(*) as total_achievements,
  COUNT(*) FILTER (WHERE a.psn_trophy_type = 'platinum') as platinums
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
GROUP BY a.platform;
