-- Check gordonops trophies in the CORRECT table (user_achievements)
SELECT 
  p.username,
  COUNT(CASE WHEN a.platform = 'psn' AND a.psn_trophy_type = 'platinum' THEN 1 END) as platinum_count,
  COUNT(CASE WHEN a.platform = 'psn' AND a.psn_trophy_type = 'gold' THEN 1 END) as gold_count,
  COUNT(CASE WHEN a.platform = 'psn' AND a.psn_trophy_type = 'silver' THEN 1 END) as silver_count,
  COUNT(CASE WHEN a.platform = 'psn' AND a.psn_trophy_type = 'bronze' THEN 1 END) as bronze_count,
  COUNT(CASE WHEN a.platform = 'psn' THEN 1 END) as total_psn_trophies,
  COUNT(CASE WHEN a.platform = 'xbox' THEN 1 END) as total_xbox_achievements,
  COALESCE(SUM(CASE WHEN a.platform = 'xbox' THEN a.xbox_gamerscore ELSE 0 END), 0) as xbox_gamerscore
FROM profiles p
LEFT JOIN user_achievements ua ON ua.user_id = p.id
LEFT JOIN achievements a ON a.id = ua.achievement_id
WHERE p.username = 'gordonops'
GROUP BY p.id, p.username;
