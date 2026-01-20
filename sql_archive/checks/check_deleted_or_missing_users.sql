-- Check if there are any recently deleted users that might still be cached
-- This looks in auth.users for recently deleted accounts

-- Option 1: Check for soft-deleted users (if using Supabase's soft delete)
SELECT 
  au.id,
  au.email,
  au.deleted_at,
  au.created_at,
  p.psn_online_id,
  p.xbox_gamertag,
  p.steam_display_name
FROM auth.users au
LEFT JOIN profiles p ON p.id = au.id
WHERE au.deleted_at IS NOT NULL
ORDER BY au.deleted_at DESC
LIMIT 10;

-- Option 2: Check for profiles without corresponding auth.users (deleted accounts)
SELECT 
  p.id,
  p.psn_online_id,
  p.xbox_gamertag,
  p.steam_display_name,
  p.created_at
FROM profiles p
LEFT JOIN auth.users au ON au.id = p.id
WHERE au.id IS NULL
LIMIT 10;

-- Option 3: Check if there's a user with StatusXP but no longer in leaderboard_cache
SELECT 
  ug.user_id,
  COUNT(DISTINCT ug.game_title_id) as game_count,
  SUM(ug.statusxp_effective) as total_statusxp,
  p.psn_online_id,
  p.xbox_gamertag,
  p.steam_display_name
FROM user_games ug
LEFT JOIN profiles p ON p.id = ug.user_id
LEFT JOIN leaderboard_cache lc ON lc.user_id = ug.user_id
WHERE lc.user_id IS NULL
  AND ug.statusxp_effective > 0
GROUP BY ug.user_id, p.psn_online_id, p.xbox_gamertag, p.steam_display_name
HAVING SUM(ug.statusxp_effective) > 0
ORDER BY total_statusxp DESC;
