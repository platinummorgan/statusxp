-- Debug: Why new user isn't showing on StatusXP leaderboard
-- Issue: User shows on Xbox leaderboard but not StatusXP leaderboard

-- Step 1: Find recent users (last 7 days)
SELECT 
  id,
  username,
  display_name,
  show_on_leaderboard,
  merged_into_user_id,
  created_at,
  psn_online_id,
  xbox_gamertag,
  steam_display_name
FROM profiles
WHERE created_at >= NOW() - INTERVAL '7 days'
ORDER BY created_at DESC;

-- Step 2: Check if they have any achievements
-- (Replace USER_ID_HERE with the actual user ID from Step 1)
SELECT 
  ua.platform_id,
  COUNT(*) as achievement_count,
  COUNT(DISTINCT ua.platform_game_id) as game_count
FROM user_achievements ua
WHERE ua.user_id = 'USER_ID_HERE'  -- Replace with actual user_id
GROUP BY ua.platform_id;

-- Step 3: Check if their achievements have base_status_xp
SELECT 
  a.platform_id,
  a.include_in_score,
  COUNT(*) as achievement_count,
  MIN(a.base_status_xp) as min_xp,
  MAX(a.base_status_xp) as max_xp,
  AVG(a.base_status_xp) as avg_xp,
  SUM(a.base_status_xp) as total_xp
FROM user_achievements ua
JOIN achievements a ON 
  a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id 
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = 'USER_ID_HERE'  -- Replace with actual user_id
GROUP BY a.platform_id, a.include_in_score;

-- Step 4: Run StatusXP calculation for this user
SELECT * FROM calculate_statusxp_with_stacks('USER_ID_HERE');  -- Replace with actual user_id

-- Step 5: Check if they're in leaderboard_cache
SELECT 
  lc.user_id,
  lc.total_statusxp,
  lc.total_game_entries,
  lc.last_updated,
  p.display_name,
  p.show_on_leaderboard,
  p.merged_into_user_id
FROM leaderboard_cache lc
JOIN profiles p ON p.id = lc.user_id
WHERE lc.user_id = 'USER_ID_HERE';  -- Replace with actual user_id

-- Step 6: Check if they're in Xbox leaderboard
SELECT 
  xlc.user_id,
  xlc.gamerscore,
  xlc.achievement_count,
  xlc.total_games,
  p.display_name
FROM xbox_leaderboard_cache xlc
JOIN profiles p ON p.id = xlc.user_id
WHERE xlc.user_id = 'USER_ID_HERE';  -- Replace with actual user_id

-- Step 7: Check leaderboard visibility settings
SELECT 
  id,
  username,
  display_name,
  show_on_leaderboard,
  merged_into_user_id,
  CASE 
    WHEN merged_into_user_id IS NOT NULL THEN 'MERGED'
    WHEN show_on_leaderboard = false THEN 'HIDDEN'
    ELSE 'VISIBLE'
  END as status
FROM profiles
WHERE id = 'USER_ID_HERE';  -- Replace with actual user_id

-- Step 8: Find users with achievements but NOT in leaderboard_cache
SELECT 
  p.id,
  p.username,
  p.display_name,
  p.show_on_leaderboard,
  p.merged_into_user_id,
  COUNT(DISTINCT ua.platform_game_id) as games_with_achievements,
  COUNT(*) as total_achievements
FROM profiles p
JOIN user_achievements ua ON ua.user_id = p.id
LEFT JOIN leaderboard_cache lc ON lc.user_id = p.id
WHERE lc.user_id IS NULL
  AND p.merged_into_user_id IS NULL
  AND p.created_at >= NOW() - INTERVAL '7 days'
GROUP BY p.id, p.username, p.display_name, p.show_on_leaderboard, p.merged_into_user_id
ORDER BY total_achievements DESC;
