-- Debug Xbox Gamerscore Issue
-- User reports: Correct 6775, showing 167755 (24.7x multiplier)

-- 1. Check current Xbox leaderboard value
SELECT user_id, display_name, gamerscore, achievement_count, total_games
FROM xbox_leaderboard_cache
WHERE display_name LIKE '%YOUR_GAMERTAG%'  -- Replace with your gamertag
ORDER BY gamerscore DESC;

-- 2. Check actual sum from user_progress (per-game, correct)
SELECT 
  user_id,
  COUNT(*) as num_games,
  SUM(current_score) as total_gamerscore_from_progress
FROM user_progress
WHERE user_id = 'YOUR_USER_ID'  -- Replace with your user_id
  AND platform_id IN (10, 11, 12)  -- Xbox platforms
GROUP BY user_id;

-- 3. Check for duplicate entries (same game, different platform_id)
SELECT 
  platform_game_id,
  COUNT(*) as count,
  array_agg(platform_id) as platform_ids,
  array_agg(current_score) as scores
FROM user_progress
WHERE user_id = 'YOUR_USER_ID'  -- Replace with your user_id
  AND platform_id IN (10, 11, 12)
GROUP BY platform_game_id
HAVING COUNT(*) > 1;

-- 4. Check how many achievements per game (causes multiplication)
SELECT 
  a.platform_game_id,
  g.name as game_name,
  up.current_score as game_score,
  COUNT(*) as num_achievements,
  (up.current_score * COUNT(*)) as multiplied_score
FROM user_achievements ua
JOIN achievements a ON 
  a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id 
  AND a.platform_achievement_id = ua.platform_achievement_id
JOIN user_progress up ON 
  up.user_id = ua.user_id 
  AND up.platform_id = a.platform_id 
  AND up.platform_game_id = a.platform_game_id
LEFT JOIN games g ON g.platform_id = a.platform_id AND g.platform_game_id = a.platform_game_id
WHERE ua.user_id = 'YOUR_USER_ID'  -- Replace with your user_id
  AND ua.platform_id IN (10, 11, 12)
GROUP BY a.platform_game_id, g.name, up.current_score
ORDER BY multiplied_score DESC;
