-- Check actual StatusXP for all users RIGHT NOW
SELECT 
  p.username,
  p.psn_online_id,
  SUM(ug.statusxp_effective) as actual_statusxp,
  COUNT(*) as total_games,
  COUNT(DISTINCT ug.game_title_id) as unique_titles
FROM profiles p
LEFT JOIN user_games ug ON ug.user_id = p.id
WHERE p.username IN ('Dex-Morgan', 'ojjm11', 'gordonops')
GROUP BY p.id, p.username, p.psn_online_id
ORDER BY actual_statusxp DESC;

-- Check if gordonops' games have statusxp_effective set
SELECT 
  COUNT(*) as total_games,
  COUNT(CASE WHEN statusxp_effective IS NULL OR statusxp_effective = 0 THEN 1 END) as zero_statusxp_games,
  SUM(statusxp_effective) as total_statusxp
FROM user_games
WHERE user_id = (SELECT id FROM profiles WHERE username = 'gordonops');
