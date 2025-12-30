-- Check Dex-Morgan's actual StatusXP calculation
SELECT 
  p.username,
  -- Count trophies by type
  COUNT(CASE WHEN a.platform = 'psn' AND a.psn_trophy_type = 'bronze' THEN 1 END) as bronze_count,
  COUNT(CASE WHEN a.platform = 'psn' AND a.psn_trophy_type = 'silver' THEN 1 END) as silver_count,
  COUNT(CASE WHEN a.platform = 'psn' AND a.psn_trophy_type = 'gold' THEN 1 END) as gold_count,
  COUNT(CASE WHEN a.platform = 'psn' AND a.psn_trophy_type = 'platinum' THEN 1 END) as platinum_count,
  COALESCE(SUM(CASE WHEN a.platform = 'xbox' THEN a.xbox_gamerscore ELSE 0 END), 0) as xbox_gamerscore,
  
  -- Calculate StatusXP (Bronze=15, Silver=30, Gold=90, Platinum=300, GS/10)
  (COUNT(CASE WHEN a.platform = 'psn' AND a.psn_trophy_type = 'bronze' THEN 1 END) * 15) +
  (COUNT(CASE WHEN a.platform = 'psn' AND a.psn_trophy_type = 'silver' THEN 1 END) * 30) +
  (COUNT(CASE WHEN a.platform = 'psn' AND a.psn_trophy_type = 'gold' THEN 1 END) * 90) +
  (COUNT(CASE WHEN a.platform = 'psn' AND a.psn_trophy_type = 'platinum' THEN 1 END) * 300) +
  (COALESCE(SUM(CASE WHEN a.platform = 'xbox' THEN a.xbox_gamerscore ELSE 0 END), 0) / 10) as calculated_statusxp
FROM profiles p
LEFT JOIN user_achievements ua ON ua.user_id = p.id
LEFT JOIN achievements a ON a.id = ua.achievement_id
WHERE p.username = 'Dex-Morgan'
GROUP BY p.id, p.username;
