-- Check what game the corrupted achievement belongs to

-- 1. Find the game with that platform_game_id
SELECT 
  platform_id,
  platform_game_id,
  name,
  metadata
FROM achievements
WHERE platform_game_id = '461173340'
  AND platform_id IN (10, 11, 12)
LIMIT 5;

-- 2. Check if game_titles has this Xbox title ID
SELECT 
  *
FROM game_titles
WHERE xbox_title_id = '461173340'
LIMIT 5;

-- 3. List all achievements for that game
SELECT 
  platform_achievement_id,
  name,
  score_value
FROM achievements
WHERE platform_game_id = '461173340'
  AND platform_id IN (10, 11, 12)
ORDER BY score_value DESC;

-- 4. How many users have achievements in this fake game?
SELECT 
  COUNT(DISTINCT user_id) as users_affected,
  COUNT(*) as total_achievements
FROM user_achievements
WHERE platform_game_id = '461173340'
  AND platform_id IN (10, 11, 12);
