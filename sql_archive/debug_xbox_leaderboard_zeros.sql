-- Debug: Why are Xbox users showing 0 gamerscore?
-- Check if user_progress has data for users with achievements

-- 1. Find users with Xbox achievements but 0 gamerscore on leaderboard
SELECT 
  xlc.user_id,
  xlc.display_name,
  xlc.gamerscore,
  xlc.achievement_count,
  xlc.total_games
FROM xbox_leaderboard_cache xlc
WHERE xlc.gamerscore = 0
  AND xlc.achievement_count > 0
ORDER BY xlc.achievement_count DESC
LIMIT 10;

-- 2. Check if these users have data in user_progress for Xbox platforms
-- Pick one user from above and check their user_progress records
WITH zero_gamerscore_users AS (
  SELECT user_id, display_name
  FROM xbox_leaderboard_cache
  WHERE gamerscore = 0 AND achievement_count > 0
  LIMIT 1
)
SELECT 
  zgu.display_name,
  up.platform_id,
  up.platform_game_id,
  up.current_score,
  up.achievements_earned,
  up.total_achievements
FROM zero_gamerscore_users zgu
LEFT JOIN user_progress up ON up.user_id = zgu.user_id
WHERE up.platform_id IN (10, 11, 12)  -- Xbox platforms
LIMIT 20;

-- 3. Check if user has achievements but no user_progress records
WITH zero_gamerscore_users AS (
  SELECT user_id, display_name
  FROM xbox_leaderboard_cache
  WHERE gamerscore = 0 AND achievement_count > 0
  LIMIT 1
)
SELECT 
  zgu.display_name,
  COUNT(DISTINCT ua.platform_game_id) as games_in_user_achievements,
  COUNT(DISTINCT ua.platform_achievement_id) as total_achievements,
  (SELECT COUNT(*) 
   FROM user_progress up2 
   WHERE up2.user_id = zgu.user_id 
     AND up2.platform_id IN (10, 11, 12)) as user_progress_records
FROM zero_gamerscore_users zgu
LEFT JOIN user_achievements ua ON ua.user_id = zgu.user_id
WHERE ua.platform_id IN (10, 11, 12)
GROUP BY zgu.user_id, zgu.display_name;

-- 4. Show actual achievements metadata for these users
WITH zero_gamerscore_users AS (
  SELECT user_id, display_name
  FROM xbox_leaderboard_cache
  WHERE gamerscore = 0 AND achievement_count > 0
  LIMIT 1
)
SELECT 
  a.platform_game_id,
  a.title as achievement_name,
  a.metadata->>'xbox_gamerscore' as xbox_gamerscore,
  a.score_value,
  COUNT(*) as count_achievements
FROM zero_gamerscore_users zgu
JOIN user_achievements ua ON ua.user_id = zgu.user_id
JOIN achievements a ON 
  a.platform_id = ua.platform_id
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.platform_id IN (10, 11, 12)
GROUP BY a.platform_game_id, a.title, a.metadata->>'xbox_gamerscore', a.score_value
ORDER BY a.platform_game_id
LIMIT 20;
