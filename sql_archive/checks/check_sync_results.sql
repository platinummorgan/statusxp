-- Check Dexmorgan6981's sync results after re-sync test
-- User ID: 84b60ad6-cb2c-484f-8953-bf814551fd7a

-- Check if games were re-added
SELECT 
  'Games Re-added' as section,
  COUNT(*) FILTER (WHERE platform_id IN (1,2,5,9)) as psn_games,
  COUNT(*) FILTER (WHERE platform_id IN (3,10,11,12)) as xbox_games,
  COUNT(*) FILTER (WHERE platform_id = 4) as steam_games,
  SUM(earned_trophies) as total_achievements_earned
FROM user_games
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Check if specific test games came back
SELECT 
  'Test Games Restored' as section,
  gt.name,
  ug.platform_id,
  ug.earned_trophies,
  ug.xbox_achievements_earned
FROM user_games ug
INNER JOIN game_titles gt ON gt.id = ug.game_title_id
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND gt.name IN (
    'Gems of War', 'DRAGON QUEST HEROES II', 'Terraria', 'DOGFIGHTER -WW2-', 'Sky: Children of the Light',
    'Exo One', 'NINJA GAIDEN Σ', 'Recompile', 'DEATHLOOP', 'PAC-MAN MUSEUM+',
    'Salt 2', 'H-Hour: World''s Elite', '逆水寒', 'S.T.A.L.K.E.R.: Call of Prypiat - Enhanced Edition', 'The Room 4: Old Sins'
  )
ORDER BY ug.platform_id, gt.name;

-- Check if achievements were written to user_achievements (this was the RLS bug)
SELECT 
  'Achievements Written' as section,
  COUNT(*) FILTER (WHERE a.platform = 'psn') as psn_achievements,
  COUNT(*) FILTER (WHERE a.platform = 'xbox') as xbox_achievements,
  COUNT(*) FILTER (WHERE a.platform = 'steam') as steam_achievements,
  COUNT(*) as total_achievements
FROM user_achievements ua
INNER JOIN achievements a ON a.id = ua.achievement_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Check for any sync errors
SELECT 
  'Sync Status' as section,
  display_name,
  last_psn_sync_at,
  psn_sync_progress,
  psn_sync_status,
  psn_sync_error,
  last_xbox_sync_at,
  xbox_sync_progress,
  xbox_sync_status,
  xbox_sync_error,
  last_steam_sync_at,
  steam_sync_progress,
  steam_sync_status,
  steam_sync_error
FROM profiles
WHERE id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Check leaderboard cache
SELECT 'PSN Leaderboard' as cache, * 
FROM psn_leaderboard_cache 
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

SELECT 'Xbox Leaderboard' as cache, * 
FROM xbox_leaderboard_cache 
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

SELECT 'Steam Leaderboard' as cache, * 
FROM steam_leaderboard_cache 
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';
