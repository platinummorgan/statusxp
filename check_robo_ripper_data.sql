-- Check if Robo Ripper has ANY data at all
SELECT 
  'user_achievements' as table_name,
  COUNT(*) as record_count
FROM user_achievements
WHERE user_id = (SELECT id FROM profiles WHERE username = 'Robo Ripper')
UNION ALL
SELECT 
  'user_progress' as table_name,
  COUNT(*) as record_count
FROM user_progress
WHERE user_id = (SELECT id FROM profiles WHERE username = 'Robo Ripper')
UNION ALL
SELECT 
  'leaderboard_cache' as table_name,
  COUNT(*) as record_count
FROM leaderboard_cache
WHERE user_id = (SELECT id FROM profiles WHERE username = 'Robo Ripper');

-- Check their profile sync status
SELECT 
  username,
  psn_sync_status,
  psn_sync_error,
  xbox_sync_status,
  xbox_sync_error,
  steam_sync_status,
  steam_sync_error
FROM profiles
WHERE username = 'Robo Ripper';
