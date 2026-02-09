-- Xbox leaderboard snapshot and underlying gamerscore totals

-- 1) Current Xbox leaderboard (top 50)
SELECT 
  xl.user_id,
  xl.display_name,
  xl.gamerscore,
  xl.achievement_count,
  xl.total_games,
  xl.updated_at
FROM xbox_leaderboard_cache xl
ORDER BY xl.gamerscore DESC
LIMIT 50;

-- 2) Raw gamerscore totals from achievements (no cap)
SELECT 
  p.id as user_id,
  COALESCE(p.xbox_gamertag, p.display_name, p.username, 'Player') as display_name,
  SUM(a.score_value) as gamerscore_raw,
  COUNT(*) as achievement_count,
  COUNT(DISTINCT a.platform_game_id) as total_games
FROM user_achievements ua
JOIN achievements a ON 
  a.platform_id = ua.platform_id
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
JOIN profiles p ON p.id = ua.user_id
WHERE ua.platform_id IN (10,11,12)
  AND p.show_on_leaderboard = true
GROUP BY p.id
ORDER BY gamerscore_raw DESC
LIMIT 50;

-- 3) Compare view vs raw for a specific user (replace gamertag)
SELECT 
  p.id as user_id,
  COALESCE(p.xbox_gamertag, p.display_name, p.username, 'Player') as display_name,
  xl.gamerscore as leaderboard_gamerscore,
  SUM(a.score_value) as raw_gamerscore
FROM profiles p
LEFT JOIN xbox_leaderboard_cache xl ON xl.user_id = p.id
LEFT JOIN user_achievements ua ON ua.user_id = p.id
LEFT JOIN achievements a ON 
  a.platform_id = ua.platform_id
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.platform_id IN (10,11,12)
  AND p.xbox_gamertag = 'XxlmThumperxX'
GROUP BY p.id, xl.gamerscore;
