-- Check PSN sync logs
SELECT 
  id,
  status,
  games_processed,
  trophies_synced,
  started_at,
  completed_at,
  error_message
FROM psn_sync_logs
WHERE user_id = (SELECT id FROM profiles LIMIT 1)
ORDER BY started_at DESC
LIMIT 5;

-- Check if there are more user_achievements that should create user_games
SELECT 
  'Total user_achievements (PSN)' as metric,
  COUNT(*) as count
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id
WHERE ua.user_id = (SELECT id FROM profiles LIMIT 1)
  AND a.platform = 'psn';

-- Cross-platform check: total games across ALL platforms
SELECT 
  p.name as platform,
  COUNT(DISTINCT ug.game_title_id) as games_in_user_games
FROM user_games ug
JOIN platforms p ON ug.platform_id = p.id
WHERE ug.user_id = (SELECT id FROM profiles LIMIT 1)
GROUP BY p.name
ORDER BY games_in_user_games DESC;
