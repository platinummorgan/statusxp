-- Check if Dex-Morgan's data actually changed in the last hour
SELECT 
  username,
  COUNT(*) as total_games,
  SUM(statusxp_effective) as total_statusxp,
  MAX(ug.updated_at) as last_game_update
FROM profiles p
JOIN user_games ug ON ug.user_id = p.id
WHERE p.username = 'Dex-Morgan'
GROUP BY p.username;

-- Check gordonops sync times to correlate
SELECT 
  username,
  last_psn_sync_at,
  psn_sync_status
FROM profiles
WHERE username IN ('Dex-Morgan', 'gordonops')
ORDER BY username;
