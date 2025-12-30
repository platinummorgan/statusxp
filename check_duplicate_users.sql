-- Find users who might be duplicates (same email or linked to same data)
-- Check for the specific user who signed up then used Apple

-- 1. Check auth.users for duplicate emails
SELECT 
  id,
  email,
  created_at,
  raw_app_meta_data->>'provider' as auth_provider,
  raw_user_meta_data
FROM auth.users
WHERE email IS NOT NULL
ORDER BY email, created_at;

-- 2. Check profiles that might belong to same person
SELECT 
  p1.id as user1_id,
  p2.id as user2_id,
  p1.display_name as user1_name,
  p2.display_name as user2_name,
  p1.psn_online_id,
  p2.psn_online_id,
  p1.xbox_gamertag,
  p2.xbox_gamertag,
  p1.created_at as user1_created,
  p2.created_at as user2_created
FROM profiles p1
JOIN profiles p2 ON p1.id < p2.id
WHERE (
  -- Same PSN account
  (p1.psn_online_id IS NOT NULL AND p1.psn_online_id = p2.psn_online_id)
  OR
  -- Same Xbox account
  (p1.xbox_gamertag IS NOT NULL AND p1.xbox_gamertag = p2.xbox_gamertag)
  OR
  -- Same Steam account
  (p1.steam_display_name IS NOT NULL AND p1.steam_display_name = p2.steam_display_name)
);

-- 3. Check leaderboard for recent duplicates
SELECT 
  p.id,
  p.display_name,
  COALESCE(p.psn_online_id, p.xbox_gamertag, p.steam_display_name) as platform_name,
  au.email,
  au.raw_app_meta_data->>'provider' as provider,
  lc.total_statusxp,
  p.created_at
FROM leaderboard_cache lc
JOIN profiles p ON p.id = lc.user_id
LEFT JOIN auth.users au ON au.id = p.id
ORDER BY p.created_at DESC
LIMIT 20;
