-- Check Xbox gamerscore totals for xXImThumperxX and Otaku

-- First, check achievements with and without 1000G cap
SELECT 
  u.email,
  COUNT(DISTINCT a.id) as achievement_count,
  SUM(a.score_value) as total_uncapped,
  SUM(LEAST(a.score_value, 1000)) as total_capped,
  COUNT(CASE WHEN a.score_value > 1000 THEN 1 END) as over_1000_count,
  MAX(a.score_value) as max_score_value
FROM users u
JOIN user_progress up ON u.id = up.user_id
JOIN achievements a ON up.platform_game_id = a.platform_game_id 
  AND up.platform_achievement_id = a.platform_achievement_id
WHERE up.platform_id IN (10, 11, 12)
  AND up.unlocked = true
  AND u.email IN ('xXImThumperxX@outlook.com', 'otaku@gmail.com')
GROUP BY u.id, u.email
ORDER BY total_uncapped DESC;

-- Check what the current xbox_leaderboard_cache view shows
SELECT * FROM xbox_leaderboard_cache
WHERE email IN ('xXImThumperxX@outlook.com', 'otaku@gmail.com')
ORDER BY total_gamerscore DESC;

-- Check for NULL or 0 score_value achievements
SELECT 
  u.email,
  COUNT(*) as null_or_zero_count
FROM users u
JOIN user_progress up ON u.id = up.user_id
JOIN achievements a ON up.platform_game_id = a.platform_game_id 
  AND up.platform_achievement_id = a.platform_achievement_id
WHERE up.platform_id IN (10, 11, 12)
  AND up.unlocked = true
  AND u.email IN ('xXImThumperxX@outlook.com', 'otaku@gmail.com')
  AND (a.score_value IS NULL OR a.score_value = 0)
GROUP BY u.id, u.email;
