-- Missing users on StatusXP leaderboard (by platform)

-- 1) Users with achievements but missing from StatusXP leaderboard_cache (all platforms)
SELECT 
  p.id as user_id,
  p.username,
  p.display_name,
  ua.platform_id,
  COUNT(*) as achievements
FROM profiles p
JOIN user_achievements ua ON ua.user_id = p.id
LEFT JOIN leaderboard_cache lc ON lc.user_id = p.id
WHERE p.merged_into_user_id IS NULL
  AND p.show_on_leaderboard = true
  AND lc.user_id IS NULL
GROUP BY p.id, p.username, p.display_name, ua.platform_id
ORDER BY achievements DESC;

-- 2) Users with achievements on Steam/Xbox but no user_progress rows for that platform
SELECT 
  p.id as user_id,
  p.username,
  p.display_name,
  ua.platform_id,
  COUNT(DISTINCT ua.platform_game_id) as games_with_achievements
FROM profiles p
JOIN user_achievements ua ON ua.user_id = p.id
LEFT JOIN user_progress up ON up.user_id = ua.user_id
  AND up.platform_id = ua.platform_id
  AND up.platform_game_id = ua.platform_game_id
WHERE p.merged_into_user_id IS NULL
  AND p.show_on_leaderboard = true
  AND ua.platform_id IN (4,10,11,12) -- Steam, Xbox
  AND up.user_id IS NULL
GROUP BY p.id, p.username, p.display_name, ua.platform_id
ORDER BY games_with_achievements DESC;

-- 3) Users with user_progress rows but zero score on Steam/Xbox
SELECT 
  p.id as user_id,
  p.username,
  p.display_name,
  up.platform_id,
  COUNT(*) as progress_rows,
  SUM(CASE WHEN up.current_score > 0 THEN 1 ELSE 0 END) as rows_with_score
FROM profiles p
JOIN user_progress up ON up.user_id = p.id
WHERE p.merged_into_user_id IS NULL
  AND p.show_on_leaderboard = true
  AND up.platform_id IN (4,10,11,12)
GROUP BY p.id, p.username, p.display_name, up.platform_id
HAVING SUM(CASE WHEN up.current_score > 0 THEN 1 ELSE 0 END) = 0
ORDER BY progress_rows DESC;

-- 4) Platform leaderboards: users missing from xbox_leaderboard_cache but with Xbox achievements
SELECT 
  p.id as user_id,
  p.username,
  p.display_name,
  COUNT(*) as achievements
FROM profiles p
JOIN user_achievements ua ON ua.user_id = p.id
LEFT JOIN xbox_leaderboard_cache xl ON xl.user_id = p.id
WHERE p.merged_into_user_id IS NULL
  AND p.show_on_leaderboard = true
  AND ua.platform_id IN (10,11,12)
  AND xl.user_id IS NULL
GROUP BY p.id, p.username, p.display_name
ORDER BY achievements DESC;

-- 5) Platform leaderboards: users missing from steam_leaderboard_cache but with Steam achievements
SELECT 
  p.id as user_id,
  p.username,
  p.display_name,
  COUNT(*) as achievements
FROM profiles p
JOIN user_achievements ua ON ua.user_id = p.id
LEFT JOIN steam_leaderboard_cache sl ON sl.user_id = p.id
WHERE p.merged_into_user_id IS NULL
  AND p.show_on_leaderboard = true
  AND ua.platform_id = 4
  AND sl.user_id IS NULL
GROUP BY p.id, p.username, p.display_name
ORDER BY achievements DESC;
