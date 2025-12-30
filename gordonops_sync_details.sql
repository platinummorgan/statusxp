-- Check gordonops sync history
SELECT 
  username,
  psn_online_id,
  last_psn_sync_at,
  psn_sync_status,
  psn_sync_progress,
  psn_sync_error,
  created_at,
  (SELECT COUNT(*) FROM user_games WHERE user_id = p.id) as game_count,
  (SELECT COUNT(*) FROM user_achievements ua JOIN achievements a ON a.id = ua.achievement_id WHERE ua.user_id = p.id AND a.platform = 'psn') as trophy_count
FROM profiles p
WHERE username = 'gordonops';
