-- Remove 5 games from each platform for Dexmorgan6981 to test re-sync
-- User ID: 84b60ad6-cb2c-484f-8953-bf814551fd7a

-- Backup the game_title_ids being removed (for reference)
CREATE TEMP TABLE removed_games AS
SELECT 
  ug.id,
  ug.game_title_id,
  ug.platform_id,
  gt.name,
  ug.earned_trophies,
  ug.xbox_achievements_earned
FROM user_games ug
INNER JOIN game_titles gt ON gt.id = ug.game_title_id
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND (
    -- PSN games
    (ug.platform_id IN (1,2,5,9) AND gt.name IN ('Gems of War', 'DRAGON QUEST HEROES II', 'Terraria', 'DOGFIGHTER -WW2-', 'Sky: Children of the Light'))
    OR
    -- Xbox games
    (ug.platform_id IN (3,10,11,12) AND gt.name IN ('Exo One', 'NINJA GAIDEN Σ', 'Recompile', 'DEATHLOOP', 'PAC-MAN MUSEUM+'))
    OR
    -- Steam games
    (ug.platform_id = 4 AND gt.name IN ('Salt 2', 'H-Hour: World''s Elite', '逆水寒', 'S.T.A.L.K.E.R.: Call of Prypiat - Enhanced Edition', 'The Room 4: Old Sins'))
  );

-- Show what will be removed
SELECT 'Games to be removed:' as info, * FROM removed_games;

-- Delete related user_achievements first (due to foreign key)
DELETE FROM user_achievements
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND achievement_id IN (
    SELECT a.id 
    FROM achievements a
    WHERE a.game_title_id IN (SELECT game_title_id FROM removed_games)
  );

-- Delete the user_games entries
DELETE FROM user_games
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND id IN (SELECT id FROM removed_games);

-- Reset sync timestamps to trigger fresh sync
UPDATE profiles
SET 
  last_psn_sync_at = NULL,
  last_steam_sync_at = NULL,
  last_xbox_sync_at = NULL,
  psn_sync_progress = 0,
  steam_sync_progress = 0,
  xbox_sync_progress = 0
WHERE id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Verify removal
SELECT 
  'After Removal' as section,
  COUNT(*) FILTER (WHERE platform_id IN (1,2,5,9)) as psn_games,
  COUNT(*) FILTER (WHERE platform_id IN (3,10,11,12)) as xbox_games,
  COUNT(*) FILTER (WHERE platform_id = 4) as steam_games,
  SUM(earned_trophies) as total_achievements_earned
FROM user_games
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Show sync status
SELECT 
  'Sync Reset Status' as section,
  display_name,
  last_psn_sync_at,
  last_xbox_sync_at,
  last_steam_sync_at,
  psn_sync_progress,
  xbox_sync_progress,
  steam_sync_progress
FROM profiles
WHERE id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

SELECT 'Ready for re-sync! Open app on phone to trigger sync.' as message;
