-- Diagnostic: Check your profile and leaderboard status
SELECT 
  id,
  display_name,
  psn_online_id,
  xbox_gamertag,
  steam_display_name,
  preferred_display_platform,
  show_on_leaderboard,
  created_at
FROM profiles
WHERE id = auth.uid();

-- Check if you're in the leaderboard cache
SELECT 
  user_id,
  total_statusxp,
  total_game_entries
FROM leaderboard_cache
WHERE user_id = auth.uid();

-- FIX 1: Ensure you're visible on leaderboards
UPDATE profiles 
SET show_on_leaderboard = true
WHERE id = auth.uid();

-- FIX 2: Set display_name from your platform names if it's null
UPDATE profiles
SET display_name = COALESCE(
  display_name,
  psn_online_id,
  xbox_gamertag,
  steam_display_name,
  'Player'
)
WHERE id = auth.uid()
  AND display_name IS NULL;

-- FIX 3: Refresh the leaderboard cache (run this to rebuild rankings)
REFRESH MATERIALIZED VIEW CONCURRENTLY leaderboard_cache;
REFRESH MATERIALIZED VIEW CONCURRENTLY leaderboard_psn_cache;
REFRESH MATERIALIZED VIEW CONCURRENTLY leaderboard_xbox_cache;
REFRESH MATERIALIZED VIEW CONCURRENTLY leaderboard_steam_cache;

-- Verify you're back
SELECT 
  lc.user_id,
  lc.total_statusxp,
  lc.total_game_entries,
  p.display_name,
  p.show_on_leaderboard
FROM leaderboard_cache lc
JOIN profiles p ON p.id = lc.user_id
WHERE lc.user_id = auth.uid();
