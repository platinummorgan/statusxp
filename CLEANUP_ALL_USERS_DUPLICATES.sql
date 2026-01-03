-- AUTOMATED CLEANUP: Remove all old game_titles without platform-specific unique IDs
-- This fixes the game merging issue for ALL users at once
-- Run this ONCE in Supabase SQL Editor

-- IMPORTANT: This will delete old game records and CASCADE delete user_games and user_achievements
-- Users will need to resync to restore their data with proper unique IDs

BEGIN;

-- 1. Count what will be deleted
SELECT 
  'Before cleanup' as status,
  COUNT(*) as total_game_titles,
  COUNT(*) FILTER (WHERE metadata ? 'psn_np_communication_id') as has_psn_id,
  COUNT(*) FILTER (WHERE metadata ? 'xbox_title_id') as has_xbox_id,
  COUNT(*) FILTER (WHERE metadata ? 'steam_app_id') as has_steam_id,
  COUNT(*) FILTER (WHERE 
    NOT (metadata ? 'psn_np_communication_id') AND
    NOT (metadata ? 'xbox_title_id') AND
    NOT (metadata ? 'steam_app_id')
  ) as no_platform_id
FROM game_titles
WHERE metadata IS NOT NULL;

-- 2. Show how many user_games will be affected
SELECT 
  'User games to be deleted' as status,
  COUNT(*) as user_games_count
FROM user_games ug
JOIN game_titles gt ON gt.id = ug.game_title_id
WHERE gt.metadata IS NOT NULL
  AND NOT (gt.metadata ? 'psn_np_communication_id')
  AND NOT (gt.metadata ? 'xbox_title_id')
  AND NOT (gt.metadata ? 'steam_app_id');

-- 3. DELETE all game_titles without platform-specific IDs
-- This cascades to user_games and user_achievements
DELETE FROM game_titles
WHERE metadata IS NOT NULL
  AND NOT (metadata ? 'psn_np_communication_id')
  AND NOT (metadata ? 'xbox_title_id')
  AND NOT (metadata ? 'steam_app_id');

-- 4. Verify cleanup
SELECT 
  'After cleanup' as status,
  COUNT(*) as total_game_titles,
  COUNT(*) FILTER (WHERE metadata ? 'psn_np_communication_id') as has_psn_id,
  COUNT(*) FILTER (WHERE metadata ? 'xbox_title_id') as has_xbox_id,
  COUNT(*) FILTER (WHERE metadata ? 'steam_app_id') as has_steam_id,
  COUNT(*) FILTER (WHERE 
    NOT (metadata ? 'psn_np_communication_id') AND
    NOT (metadata ? 'xbox_title_id') AND
    NOT (metadata ? 'steam_app_id')
  ) as no_platform_id
FROM game_titles
WHERE metadata IS NOT NULL;

COMMIT;

-- AFTER RUNNING THIS:
-- 1. All users will have reduced game counts
-- 2. Tell users to resync their platforms
-- 3. Syncs will recreate games with proper unique IDs
-- 4. No more game merging for anyone
