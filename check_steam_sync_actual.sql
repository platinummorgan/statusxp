-- Check Steam sync status
SELECT 
  steam_sync_status,
  steam_sync_progress,
  steam_sync_error,
  last_steam_sync_at,
  steam_display_name,
  steam_id
FROM profiles
WHERE id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Check Steam sync logs
SELECT 
  id,
  status,
  started_at,
  completed_at,
  games_processed,
  achievements_synced,
  error_message
FROM steam_sync_logs
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
ORDER BY started_at DESC
LIMIT 5;

-- Check if there are ANY Steam games in user_games
SELECT COUNT(*) as steam_games
FROM user_games ug
JOIN platforms p ON ug.platform_id = p.id
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND p.code = 'Steam';
