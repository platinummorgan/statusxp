-- Check how many games have NULL statusxp_effective
SELECT 
  p.username,
  COUNT(*) as total_games,
  COUNT(CASE WHEN ug.statusxp_effective IS NULL THEN 1 END) as null_statusxp_games,
  COUNT(CASE WHEN ug.statusxp_effective IS NOT NULL THEN 1 END) as has_statusxp_games
FROM profiles p
JOIN user_games ug ON ug.user_id = p.id
WHERE p.username = 'Dex-Morgan'
GROUP BY p.username;
