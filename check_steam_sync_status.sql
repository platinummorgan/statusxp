-- Check current Steam sync status
SELECT 
  id,
  steam_sync_status,
  steam_sync_progress,
  steam_sync_error,
  last_steam_sync_at
FROM profiles
WHERE id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Check how many Steam games were synced
SELECT COUNT(*) as steam_games_synced
FROM user_games
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND platform = 'steam';

-- Check total Steam achievements synced
SELECT COUNT(*) as steam_achievements_synced
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND ua.platform = 'steam';
