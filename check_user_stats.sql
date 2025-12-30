-- Check user stats for X_imThumper_X
WITH user_data AS (
  SELECT id FROM profiles WHERE username = 'X_imThumper_X'
)
SELECT 
  'PSN Platinums' as stat_type,
  COUNT(CASE WHEN t.tier = 'platinum' THEN 1 END) as count
FROM user_data u
LEFT JOIN user_trophies ut ON ut.user_id = u.id
LEFT JOIN trophies t ON t.id = ut.trophy_id

UNION ALL

SELECT 
  'PSN Total Trophies' as stat_type,
  COUNT(*) as count
FROM user_data u
LEFT JOIN user_trophies ut ON ut.user_id = u.id

UNION ALL

SELECT 
  'PSN Bronze' as stat_type,
  COUNT(CASE WHEN t.tier = 'bronze' THEN 1 END) as count
FROM user_data u
LEFT JOIN user_trophies ut ON ut.user_id = u.id
LEFT JOIN trophies t ON t.id = ut.trophy_id

UNION ALL

SELECT 
  'PSN Silver' as stat_type,
  COUNT(CASE WHEN t.tier = 'silver' THEN 1 END) as count
FROM user_data u
LEFT JOIN user_trophies ut ON ut.user_id = u.id
LEFT JOIN trophies t ON t.id = ut.trophy_id

UNION ALL

SELECT 
  'PSN Gold' as stat_type,
  COUNT(CASE WHEN t.tier = 'gold' THEN 1 END) as count
FROM user_data u
LEFT JOIN user_trophies ut ON ut.user_id = u.id
LEFT JOIN trophies t ON t.id = ut.trophy_id

UNION ALL

SELECT 
  'Xbox Total Achievements' as stat_type,
  COUNT(CASE WHEN a.platform = 'xbox' THEN 1 END) as count
FROM user_data u
LEFT JOIN user_achievements ua ON ua.user_id = u.id
LEFT JOIN achievements a ON a.id = ua.achievement_id

UNION ALL

SELECT 
  'Xbox Gamerscore' as stat_type,
  COALESCE(SUM(CASE WHEN a.platform = 'xbox' THEN a.xbox_gamerscore ELSE 0 END), 0) as count
FROM user_data u
LEFT JOIN user_achievements ua ON ua.user_id = u.id
LEFT JOIN achievements a ON a.id = ua.achievement_id

UNION ALL

SELECT 
  'Total Games' as stat_type,
  COUNT(*) as count
FROM user_data u
LEFT JOIN user_games ug ON ug.user_id = u.id;
