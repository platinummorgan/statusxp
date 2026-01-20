-- Monitor PSN sync progress and check if achievements are being written
-- Run this repeatedly while sync is in progress

-- 1. Current sync status
SELECT 
  'Sync Status' as check,
  psn_sync_status,
  psn_sync_progress,
  psn_sync_error,
  last_psn_sync_at,
  (last_psn_sync_at > NOW() - INTERVAL '5 minutes') as synced_recently
FROM profiles
WHERE id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'::uuid;

-- 2. Game counts
SELECT 
  'Game Counts' as check,
  COUNT(*) FILTER (WHERE platform_id IN (1,2,5,9)) as psn_games,
  COUNT(*) FILTER (WHERE platform_id IN (3)) as xbox_games,
  COUNT(*) FILTER (WHERE platform_id IN (4,6,7,8)) as steam_games,
  COUNT(*) as total_games
FROM user_games
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'::uuid;

-- 3. Achievement counts in user_achievements
SELECT 
  'Achievement Counts' as check,
  COUNT(*) FILTER (WHERE a.platform = 'psn') as psn_achievements,
  COUNT(*) FILTER (WHERE a.platform = 'xbox') as xbox_achievements,
  COUNT(*) FILTER (WHERE a.platform = 'steam') as steam_achievements,
  COUNT(*) as total_achievements
FROM user_achievements ua
INNER JOIN achievements a ON a.id = ua.achievement_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'::uuid;

-- 4. Check if test games have achievements now
SELECT 
  'Test Games Achievement Status' as check,
  gt.name as game_name,
  ug.earned_trophies as api_earned,
  COUNT(ua.achievement_id) as achievements_stored,
  CASE 
    WHEN ug.earned_trophies > 0 AND COUNT(ua.achievement_id) = 0 THEN '❌ MISSING'
    WHEN COUNT(ua.achievement_id) > 0 THEN '✅ WRITTEN'
    ELSE '⚪ NO TROPHIES'
  END as status
FROM user_games ug
INNER JOIN game_titles gt ON gt.id = ug.game_title_id
LEFT JOIN achievements a ON a.game_title_id = gt.id AND a.platform = 'psn'
LEFT JOIN user_achievements ua ON ua.achievement_id = a.id AND ua.user_id = ug.user_id
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'::uuid
AND gt.name IN (
  'Gems of War',
  'DRAGON QUEST HEROES II', 
  'Terraria',
  'DOGFIGHTER -WW2-',
  'Sky: Children of the Light'
)
GROUP BY gt.name, ug.earned_trophies
ORDER BY gt.name;

-- 5. Show recent sync log entries
SELECT 
  'Recent Sync Logs' as check,
  id,
  status,
  started_at,
  completed_at,
  games_processed,
  achievements_synced,
  error_message
FROM psn_sync_logs
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'::uuid
ORDER BY started_at DESC
LIMIT 3;
