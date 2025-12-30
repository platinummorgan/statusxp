-- Check user's platinum and game counts
SELECT 
  p.username,
  -- Platinum count
  COUNT(DISTINCT CASE WHEN a.psn_trophy_type = 'platinum' THEN a.id END) as platinum_count,
  -- Total games
  (SELECT COUNT(*) FROM user_games ug WHERE ug.user_id = p.id) as total_games,
  -- PSN games
  (SELECT COUNT(*) FROM user_games ug JOIN platforms pl ON ug.platform_id = pl.id 
   WHERE ug.user_id = p.id AND pl.code IN ('PS3', 'PS4', 'PS5', 'PSVITA')) as psn_games,
  -- Xbox games
  (SELECT COUNT(*) FROM user_games ug JOIN platforms pl ON ug.platform_id = pl.id 
   WHERE ug.user_id = p.id AND pl.code = 'XBOXONE') as xbox_games,
  -- Steam games
  (SELECT COUNT(*) FROM user_games ug JOIN platforms pl ON ug.platform_id = pl.id 
   WHERE ug.user_id = p.id AND pl.code = 'Steam') as steam_games
FROM profiles p
LEFT JOIN user_achievements ua ON p.id = ua.user_id
LEFT JOIN achievements a ON ua.achievement_id = a.id AND a.platform = 'psn'
WHERE p.username IN ('Dex-Morgan', 'ojjm11', 'DemoTester')
GROUP BY p.id, p.username
ORDER BY platinum_count DESC;
