-- Real-time sync monitoring for Dexmorgan6981
-- User ID: 84b60ad6-cb2c-484f-8953-bf814551fd7a

-- Check current sync status
SELECT 
  'Sync Progress' as section,
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

-- Check if PSN games were re-added
SELECT 
  'PSN Games Count' as check,
  COUNT(*) as current_count,
  319 as expected_count
FROM user_games
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND platform_id IN (1,2,5,9);

-- Check if Xbox games were re-added
SELECT 
  'Xbox Games Count' as check,
  COUNT(*) as current_count,
  27 as expected_count
FROM user_games
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND platform_id IN (3,10,11,12);

-- Check if Steam games were re-added
SELECT 
  'Steam Games Count' as check,
  COUNT(*) as current_count,
  32 as expected_count
FROM user_games
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND platform_id = 4;

-- Check if the removed PSN games came back
SELECT 
  'Removed PSN Games Status' as check,
  gt.name,
  ug.earned_trophies
FROM user_games ug
INNER JOIN game_titles gt ON gt.id = ug.game_title_id
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND gt.name IN ('Gems of War', 'DRAGON QUEST HEROES II', 'Terraria', 'DOGFIGHTER -WW2-', 'Sky: Children of the Light')
  AND ug.platform_id IN (1,2,5,9);
