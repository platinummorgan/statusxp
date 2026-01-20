-- Find user(s) showing as "Unknown" in StatusXP leaderboard
-- These users have entries in leaderboard_cache but no platform identifiers

-- Option 1: Check leaderboard_cache entries with no platform identifiers
SELECT 
  lc.user_id,
  lc.total_statusxp,
  lc.total_game_entries,
  p.id as profile_id,
  p.psn_online_id,
  p.xbox_gamertag,
  p.steam_display_name,
  p.steam_id,
  au.email,
  au.created_at as user_created_at
FROM leaderboard_cache lc
LEFT JOIN profiles p ON p.id = lc.user_id
LEFT JOIN auth.users au ON au.id = lc.user_id
WHERE p.psn_online_id IS NULL 
  AND p.xbox_gamertag IS NULL 
  AND p.steam_display_name IS NULL
ORDER BY lc.total_statusxp DESC;

-- Option 2: Check if there are orphaned leaderboard_cache entries (no matching profile)
SELECT 
  lc.user_id,
  lc.total_statusxp,
  lc.total_game_entries,
  au.email
FROM leaderboard_cache lc
LEFT JOIN profiles p ON p.id = lc.user_id
LEFT JOIN auth.users au ON au.id = lc.user_id
WHERE p.id IS NULL
ORDER BY lc.total_statusxp DESC;

-- Option 3: Check if there are user_games entries for this unknown user
SELECT 
  ug.user_id,
  COUNT(DISTINCT ug.game_title_id) as game_count,
  SUM(ug.statusxp_effective) as total_statusxp,
  ARRAY_AGG(DISTINCT ug.platform_id) as platforms,
  p.psn_online_id,
  p.xbox_gamertag,
  p.steam_display_name
FROM user_games ug
LEFT JOIN profiles p ON p.id = ug.user_id
WHERE p.psn_online_id IS NULL 
  AND p.xbox_gamertag IS NULL 
  AND p.steam_display_name IS NULL
GROUP BY ug.user_id, p.psn_online_id, p.xbox_gamertag, p.steam_display_name;
