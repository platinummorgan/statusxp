-- Investigate the "Unknown" user showing in the leaderboard
-- Check for various edge cases

-- Option 1: Find users with empty string platform names (not NULL, but '')
SELECT 
  lc.user_id,
  lc.total_statusxp,
  lc.total_game_entries,
  p.id as profile_id,
  COALESCE(p.psn_online_id, '(null)') as psn,
  COALESCE(p.xbox_gamertag, '(null)') as xbox,
  COALESCE(p.steam_display_name, '(null)') as steam,
  LENGTH(COALESCE(p.psn_online_id, '')) as psn_length,
  LENGTH(COALESCE(p.xbox_gamertag, '')) as xbox_length,
  LENGTH(COALESCE(p.steam_display_name, '')) as steam_length,
  au.email
FROM leaderboard_cache lc
LEFT JOIN profiles p ON p.id = lc.user_id
LEFT JOIN auth.users au ON au.id = lc.user_id
WHERE (p.psn_online_id = '' OR p.xbox_gamertag = '' OR p.steam_display_name = '')
   OR (TRIM(COALESCE(p.psn_online_id, '')) = '' 
       AND TRIM(COALESCE(p.xbox_gamertag, '')) = '' 
       AND TRIM(COALESCE(p.steam_display_name, '')) = '')
ORDER BY lc.total_statusxp DESC;

-- Option 2: Show ALL users in leaderboard (to see what's actually there)
SELECT 
  lc.user_id,
  lc.total_statusxp,
  lc.total_game_entries,
  COALESCE(p.psn_online_id, p.xbox_gamertag, p.steam_display_name, 'NO NAME') as display_name,
  p.psn_online_id,
  p.xbox_gamertag,
  p.steam_display_name,
  au.email
FROM leaderboard_cache lc
LEFT JOIN profiles p ON p.id = lc.user_id
LEFT JOIN auth.users au ON au.id = lc.user_id
ORDER BY lc.total_statusxp DESC
LIMIT 20;

-- Option 3: Check for profiles with exactly the text "Unknown" as a name
SELECT 
  lc.user_id,
  lc.total_statusxp,
  lc.total_game_entries,
  p.psn_online_id,
  p.xbox_gamertag,
  p.steam_display_name,
  au.email
FROM leaderboard_cache lc
LEFT JOIN profiles p ON p.id = lc.user_id
LEFT JOIN auth.users au ON au.id = lc.user_id
WHERE p.psn_online_id = 'Unknown' 
   OR p.xbox_gamertag = 'Unknown' 
   OR p.steam_display_name = 'Unknown'
ORDER BY lc.total_statusxp DESC;
