-- Check if trophies ended up in achievements table by mistake
SELECT 
  COUNT(*) as total_achievements,
  COUNT(CASE WHEN platform = 'psn' THEN 1 END) as psn_achievements,
  COUNT(CASE WHEN platform = 'xbox' THEN 1 END) as xbox_achievements,
  COUNT(CASE WHEN platform = 'steam' THEN 1 END) as steam_achievements
FROM achievements;

-- Also check user_achievements
SELECT 
  'user_achievements' as table_name,
  COUNT(*) as total_rows,
  COUNT(CASE WHEN a.platform = 'psn' THEN 1 END) as psn_count
FROM user_achievements ua
JOIN achievements a ON a.id = ua.achievement_id;
