-- Check all users' Xbox gamerscore
SELECT 
  p.username,
  p.id as user_id,
  SUM(ug.xbox_current_gamerscore) as total_gamerscore,
  COUNT(DISTINCT ug.game_title_id) as xbox_games_count
FROM profiles p
INNER JOIN user_games ug ON p.id = ug.user_id
INNER JOIN platforms pl ON ug.platform_id = pl.id
WHERE pl.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')
GROUP BY p.username, p.id
ORDER BY total_gamerscore DESC;
