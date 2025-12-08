-- Check data available for leaderboards

-- 1. StatusXP Leaderboard (all users)
SELECT 
  p.id as user_id,
  COALESCE(p.display_name, p.psn_online_id, p.xbox_gamertag, p.steam_display_name, 'Unknown') as display_name,
  p.avatar_url,
  COALESCE(ug_summary.total_statusxp, 0) as total_statusxp,
  COALESCE(ug_summary.total_games, 0) as total_games
FROM profiles p
LEFT JOIN (
  SELECT 
    user_id,
    SUM(statusxp_effective) as total_statusxp,
    COUNT(*) as total_games
  FROM user_games
  GROUP BY user_id
) ug_summary ON p.id = ug_summary.user_id
ORDER BY total_statusxp DESC
LIMIT 100;

-- 2. Platinum Count Leaderboard (PSN only)
SELECT 
  p.id as user_id,
  COALESCE(p.display_name, p.psn_online_id, 'Unknown') as display_name,
  p.avatar_url,
  COUNT(*) as platinum_count,
  COUNT(DISTINCT a.game_title_id) as games_with_platinums
FROM profiles p
JOIN user_achievements ua ON p.id = ua.user_id
JOIN achievements a ON ua.achievement_id = a.id
WHERE a.platform = 'psn' AND a.psn_trophy_type = 'platinum'
GROUP BY p.id, p.display_name, p.psn_online_id, p.avatar_url
ORDER BY platinum_count DESC
LIMIT 100;

-- 3. Achievement Score Leaderboard (Xbox)
SELECT 
  p.id as user_id,
  COALESCE(p.display_name, p.xbox_gamertag, 'Unknown') as display_name,
  p.avatar_url,
  COUNT(*) as total_achievements,
  COUNT(DISTINCT a.game_title_id) as games_count
FROM profiles p
JOIN user_achievements ua ON p.id = ua.user_id
JOIN achievements a ON ua.achievement_id = a.id
WHERE a.platform = 'xbox'
GROUP BY p.id, p.display_name, p.xbox_gamertag, p.avatar_url
ORDER BY total_achievements DESC
LIMIT 100;

-- 4. Steam Score Leaderboard
SELECT 
  p.id as user_id,
  COALESCE(p.display_name, p.steam_display_name, 'Unknown') as display_name,
  p.avatar_url,
  COUNT(*) as total_achievements,
  COUNT(DISTINCT a.game_title_id) as games_count
FROM profiles p
JOIN user_achievements ua ON p.id = ua.user_id
JOIN achievements a ON ua.achievement_id = a.id
WHERE a.platform = 'steam'
GROUP BY p.id, p.display_name, p.steam_display_name, p.avatar_url
ORDER BY total_achievements DESC
LIMIT 100;
