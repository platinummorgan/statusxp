-- Diagnostic query to check why Steam games aren't showing in user's game list
-- Run this with the user's ID to investigate

-- Replace with actual user_id
\set user_id 'USER_ID_HERE'

-- 1. Check if user has Steam games in user_progress table
SELECT 
  'Steam games in user_progress' as check_name,
  COUNT(*) as count,
  jsonb_agg(jsonb_build_object(
    'platform_game_id', platform_game_id,
    'game_name', (SELECT name FROM games g WHERE g.platform_id = up.platform_id AND g.platform_game_id = up.platform_game_id),
    'achievements_earned', achievements_earned,
    'total_achievements', total_achievements,
    'completion', completion_percentage
  )) as details
FROM user_progress up
WHERE user_id = :'user_id'::uuid
  AND platform_id = 4; -- Steam

-- 2. Check if user has Steam achievements in user_achievements
SELECT 
  'Steam achievements synced' as check_name,
  COUNT(DISTINCT platform_game_id) as unique_games,
  COUNT(*) as total_achievements,
  jsonb_agg(DISTINCT platform_game_id) as game_ids
FROM user_achievements
WHERE user_id = :'user_id'::uuid
  AND platform_id = 4; -- Steam

-- 3. Check if Steam games exist in games table
SELECT 
  'Steam games in games table' as check_name,
  COUNT(*) as count,
  jsonb_agg(jsonb_build_object(
    'platform_game_id', platform_game_id,
    'name', name,
    'cover_url', cover_url
  ) ORDER BY name) as details
FROM games
WHERE platform_id = 4
  AND platform_game_id IN (
    SELECT DISTINCT platform_game_id 
    FROM user_progress 
    WHERE user_id = :'user_id'::uuid 
      AND platform_id = 4
  );

-- 4. Check user_games VIEW output (this is what get_user_grouped_games uses)
SELECT 
  'Steam games in user_games view' as check_name,
  COUNT(*) as count,
  jsonb_agg(jsonb_build_object(
    'platform_id', platform_id,
    'game_title', game_title,
    'earned_trophies', earned_trophies,
    'total_trophies', total_trophies,
    'completion_percent', completion_percent,
    'last_played_at', last_played_at
  )) as details
FROM user_games
WHERE user_id = :'user_id'::uuid
  AND platform_id = 4; -- Steam

-- 5. Test get_user_grouped_games function directly
SELECT 
  'get_user_grouped_games result' as check_name,
  COUNT(*) as count,
  jsonb_agg(jsonb_build_object(
    'group_id', group_id,
    'name', name,
    'platforms', platforms
  )) as details
FROM get_user_grouped_games(:'user_id'::uuid)
WHERE EXISTS (
  SELECT 1 FROM jsonb_array_elements(platforms) as p
  WHERE p->>'code' = 'steam'
);

-- 6. Check Steam profile sync status
SELECT 
  'Steam sync status' as check_name,
  jsonb_build_object(
    'steam_id', steam_id,
    'steam_display_name', steam_display_name,
    'steam_sync_status', steam_sync_status,
    'last_steam_sync_at', last_steam_sync_at,
    'steam_sync_error', steam_sync_error,
    'steam_sync_progress', steam_sync_progress
  ) as details
FROM profiles
WHERE id = :'user_id'::uuid;

-- 7. Check platform_id mapping
SELECT 
  'Platform mappings' as check_name,
  jsonb_object_agg(code, id) as platform_mapping
FROM platforms;
