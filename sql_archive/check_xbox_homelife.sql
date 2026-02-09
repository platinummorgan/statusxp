-- Diagnose Xbox gamerscore mismatch for Vs Homelife

-- 1) Leaderboard vs raw gamerscore
SELECT 
  p.id as user_id,
  COALESCE(p.xbox_gamertag, p.display_name, p.username, 'Player') as display_name,
  xl.gamerscore as leaderboard_gamerscore,
  SUM(a.score_value) as raw_gamerscore,
  COUNT(*) as achievement_count,
  COUNT(DISTINCT a.platform_game_id) as total_games
FROM profiles p
LEFT JOIN xbox_leaderboard_cache xl ON xl.user_id = p.id
LEFT JOIN user_achievements ua ON ua.user_id = p.id
LEFT JOIN achievements a ON 
  a.platform_id = ua.platform_id
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.platform_id IN (10,11,12)
  AND p.xbox_gamertag = 'Vs Homelife'
GROUP BY p.id, xl.gamerscore;

-- 2) Count achievements missing score_value
SELECT 
  COUNT(*) as missing_score_value
FROM user_achievements ua
JOIN achievements a ON 
  a.platform_id = ua.platform_id
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
JOIN profiles p ON p.id = ua.user_id
WHERE ua.platform_id IN (10,11,12)
  AND p.xbox_gamertag = 'Vs Homelife'
  AND (a.score_value IS NULL OR a.score_value = 0);

-- 3) Compare with user_progress totals (for sanity)
SELECT 
  SUM(up.current_score) as statusxp_total,
  COUNT(DISTINCT up.platform_game_id) as games_in_progress
FROM user_progress up
JOIN profiles p ON p.id = up.user_id
WHERE up.platform_id IN (10,11,12)
  AND p.xbox_gamertag = 'Vs Homelife';
