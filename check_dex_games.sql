-- Check Dex-Morgan's actual game count by platform
SELECT 
  p.username,
  COUNT(DISTINCT ug.id) as total_user_games,
  COUNT(DISTINCT CASE WHEN pl.code LIKE 'PS%' THEN ug.id END) as psn_games,
  COUNT(DISTINCT CASE WHEN pl.code = 'XBOXONE' THEN ug.id END) as xbox_games,
  COUNT(DISTINCT CASE WHEN pl.code = 'Steam' THEN ug.id END) as steam_games
FROM profiles p
LEFT JOIN user_games ug ON ug.user_id = p.id
LEFT JOIN platforms pl ON ug.platform_id = pl.id
WHERE p.username = 'Dex-Morgan'
GROUP BY p.id, p.username;
