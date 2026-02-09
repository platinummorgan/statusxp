-- Diagnostic: Check Xbox Gamerscore calculation
-- Issue #8: Xbox Leaderboards calculating impossibly high Gamerscores

-- Check a sample user's Xbox data
SELECT 
  ua.user_id,
  p.xbox_gamertag,
  COUNT(*) as total_xbox_achievements,
  COUNT(DISTINCT a.platform_game_id) as unique_games,
  SUM(up.current_score) as calculated_gamerscore_from_sum,
  -- Check if we're summing duplicate records
  COUNT(DISTINCT (up.user_id, up.platform_id, up.platform_game_id)) as unique_progress_records
FROM user_achievements ua
JOIN achievements a ON 
  a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id 
  AND a.platform_achievement_id = ua.platform_achievement_id
JOIN profiles p ON p.id = ua.user_id
LEFT JOIN user_progress up ON 
  up.user_id = ua.user_id 
  AND up.platform_id = a.platform_id 
  AND up.platform_game_id = a.platform_game_id
WHERE ua.platform_id IN (10, 11, 12) -- Xbox 360, One, Series X/S
  AND p.show_on_leaderboard = true
GROUP BY ua.user_id, p.xbox_gamertag
ORDER BY calculated_gamerscore_from_sum DESC
LIMIT 10;

-- Check if current_score is per-game or total
SELECT 
  up.user_id,
  up.platform_id,
  up.platform_game_id,
  up.current_score,
  up.achievements_earned,
  up.total_achievements,
  g.name as game_name
FROM user_progress up
JOIN games g ON g.platform_id = up.platform_id AND g.platform_game_id = up.platform_game_id
WHERE up.platform_id IN (10, 11, 12)
  AND up.current_score > 0
ORDER BY up.current_score DESC
LIMIT 20;

-- The correct gamerscore should be the SUM of current_score from user_progress (per game)
-- NOT from individual achievements
-- Each user_progress record represents ONE GAME with current_score = total gamerscore for that game
