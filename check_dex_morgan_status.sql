-- Check Dex-Morgan's account status
SELECT 
  p.id,
  au.email,
  COALESCE(p.psn_online_id, p.xbox_gamertag) as platform_name,
  COUNT(DISTINCT ug.game_title_id) as game_count,
  SUM(ug.statusxp_effective) as actual_statusxp,
  lc.total_statusxp as cached_statusxp,
  lc.total_game_entries as cached_game_entries
FROM profiles p
LEFT JOIN auth.users au ON au.id = p.id
LEFT JOIN user_games ug ON ug.user_id = p.id
LEFT JOIN leaderboard_cache lc ON lc.user_id = p.id
WHERE p.psn_online_id = 'Dex-Morgan' OR p.xbox_gamertag = 'Dex-Morgan'
GROUP BY p.id, au.email, p.psn_online_id, p.xbox_gamertag, lc.total_statusxp, lc.total_game_entries;

-- Also check the raw user_games data
SELECT 
  platform_id,
  COUNT(*) as game_count,
  SUM(statusxp_effective) as platform_statusxp
FROM user_games ug
JOIN profiles p ON p.id = ug.user_id
WHERE p.psn_online_id = 'Dex-Morgan' OR p.xbox_gamertag = 'Dex-Morgan'
GROUP BY platform_id;
