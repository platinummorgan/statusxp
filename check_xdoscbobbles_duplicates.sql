-- Check if xdoscbobbles has duplicate accounts that should be merged

-- Both accounts with "xdoscbobbles"
SELECT 
  p.id,
  au.email,
  au.created_at as account_created,
  p.psn_online_id,
  p.psn_account_id,
  p.xbox_gamertag,
  p.xbox_xuid,
  p.steam_display_name,
  p.steam_id,
  p.preferred_display_platform,
  lc.total_statusxp,
  lc.total_game_entries,
  p.last_psn_sync_at,
  p.last_xbox_sync_at,
  p.last_steam_sync_at
FROM profiles p
LEFT JOIN auth.users au ON au.id = p.id
LEFT JOIN leaderboard_cache lc ON lc.user_id = p.id
WHERE p.xbox_gamertag = 'xdoscbobbles' 
   OR p.psn_online_id = 'xdoscbobbles'
ORDER BY au.created_at;

-- Check if they have the same Xbox XUID (would confirm same Xbox account)
SELECT 
  xbox_xuid,
  COUNT(*) as account_count,
  ARRAY_AGG(id) as user_ids,
  ARRAY_AGG(xbox_gamertag) as gamertags
FROM profiles
WHERE xbox_xuid IS NOT NULL
GROUP BY xbox_xuid
HAVING COUNT(*) > 1;
