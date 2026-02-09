-- Check BOTH accounts to understand the situation
SELECT 
  au.id,
  au.email,
  au.created_at,
  au.last_sign_in_at,
  p.display_name,
  p.xbox_xuid,
  p.xbox_gamertag,
  p.psn_online_id,
  p.steam_id,
  p.xbox_sync_status,
  p.psn_sync_status,
  p.steam_sync_status
FROM auth.users au
LEFT JOIN profiles p ON p.id = au.id
WHERE au.email IN ('ojjm11@outlook.com', 'oscarmargan20@gmail.com')
ORDER BY au.last_sign_in_at DESC;
