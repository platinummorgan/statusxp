-- Find who has the most platinums
SELECT 
  p.username,
  p.psn_online_id,
  COUNT(CASE WHEN a.platform = 'psn' AND a.psn_trophy_type = 'platinum' THEN 1 END) as platinum_count,
  COUNT(CASE WHEN a.platform = 'psn' THEN 1 END) as total_psn_trophies
FROM profiles p
LEFT JOIN user_achievements ua ON ua.user_id = p.id
LEFT JOIN achievements a ON a.id = ua.achievement_id
GROUP BY p.id, p.username, p.psn_online_id
ORDER BY platinum_count DESC
LIMIT 5;
