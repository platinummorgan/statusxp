-- EMERGENCY FIX: Get you back on leaderboards NOW

-- Step 1: Check current state
SELECT 
  'Current Profile State' as check_type,
  id,
  display_name,
  psn_online_id,
  xbox_gamertag,
  steam_display_name,
  preferred_display_platform,
  show_on_leaderboard,
  (SELECT COUNT(*) FROM user_games WHERE user_id = profiles.id) as game_count,
  (SELECT SUM(statusxp) FROM user_games WHERE user_id = profiles.id) as total_xp
FROM profiles
WHERE id = auth.uid();

-- Step 2: FORCE FIX - Set everything to make you visible
UPDATE profiles 
SET 
  show_on_leaderboard = true,
  display_name = COALESCE(
    NULLIF(display_name, ''),
    psn_online_id,
    xbox_gamertag,
    steam_display_name
  ),
  preferred_display_platform = COALESCE(
    NULLIF(preferred_display_platform, ''),
    CASE 
      WHEN psn_online_id IS NOT NULL THEN 'psn'
      WHEN xbox_gamertag IS NOT NULL THEN 'xbox'
      WHEN steam_display_name IS NOT NULL THEN 'steam'
      ELSE 'psn'
    END
  )
WHERE id = auth.uid();

-- Step 3: Check leaderboard_cache - are you in it?
SELECT 
  'Leaderboard Cache Check' as check_type,
  user_id,
  total_statusxp,
  total_game_entries
FROM leaderboard_cache
WHERE user_id = auth.uid();

-- Step 4: NUCLEAR OPTION - Completely rebuild all leaderboard caches
REFRESH MATERIALIZED VIEW CONCURRENTLY leaderboard_cache;
REFRESH MATERIALIZED VIEW CONCURRENTLY leaderboard_psn_cache;
REFRESH MATERIALIZED VIEW CONCURRENTLY leaderboard_xbox_cache;
REFRESH MATERIALIZED VIEW CONCURRENTLY leaderboard_steam_cache;

-- Step 5: Verify you're back on ALL leaderboards
SELECT 
  'Global Leaderboard' as board,
  (SELECT COUNT(*) + 1 FROM leaderboard_cache WHERE total_statusxp > (SELECT total_statusxp FROM leaderboard_cache WHERE user_id = auth.uid())) as rank,
  lc.total_statusxp,
  lc.total_game_entries,
  p.display_name
FROM leaderboard_cache lc
JOIN profiles p ON p.id = lc.user_id
WHERE lc.user_id = auth.uid()

UNION ALL

SELECT 
  'PSN Leaderboard' as board,
  (SELECT COUNT(*) + 1 FROM leaderboard_psn_cache WHERE platinum_count > (SELECT platinum_count FROM leaderboard_psn_cache WHERE user_id = auth.uid())) as rank,
  lpc.platinum_count,
  lpc.total_games,
  p.display_name
FROM leaderboard_psn_cache lpc
JOIN profiles p ON p.id = lpc.user_id
WHERE lpc.user_id = auth.uid()

UNION ALL

SELECT 
  'Xbox Leaderboard' as board,
  (SELECT COUNT(*) + 1 FROM leaderboard_xbox_cache WHERE achievement_count > (SELECT achievement_count FROM leaderboard_xbox_cache WHERE user_id = auth.uid())) as rank,
  lxc.achievement_count,
  lxc.total_games,
  p.display_name
FROM leaderboard_xbox_cache lxc
JOIN profiles p ON p.id = lxc.user_id
WHERE lxc.user_id = auth.uid()

UNION ALL

SELECT 
  'Steam Leaderboard' as board,
  (SELECT COUNT(*) + 1 FROM leaderboard_steam_cache WHERE achievement_count > (SELECT achievement_count FROM leaderboard_steam_cache WHERE user_id = auth.uid())) as rank,
  lsc.achievement_count,
  lsc.total_games,
  p.display_name
FROM leaderboard_steam_cache lsc
JOIN profiles p ON p.id = lsc.user_id
WHERE lsc.user_id = auth.uid();
