-- ============================================================================
-- Diagnose Steam Platform ID Issue
-- ============================================================================
-- User sees Steam achievements but no Steam games in user_progress
-- ============================================================================

-- 1. Check what platform IDs exist in user_achievements for this user
SELECT 
  platform_id,
  COUNT(DISTINCT platform_game_id) as unique_games,
  COUNT(*) as total_achievements
FROM user_achievements
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
GROUP BY platform_id
ORDER BY platform_id;

-- 2. Check what platform IDs exist in games table
SELECT 
  platform_id,
  COUNT(*) as game_count,
  CASE 
    WHEN platform_id = 1 THEN 'PSN'
    WHEN platform_id = 2 THEN 'PS3?'
    WHEN platform_id = 3 THEN 'PS4?'
    WHEN platform_id = 4 THEN 'PS5?'
    WHEN platform_id = 5 THEN 'Steam'
    WHEN platform_id = 10 THEN 'Xbox360'
    WHEN platform_id = 11 THEN 'XboxOne'
    WHEN platform_id = 12 THEN 'XboxSeriesX'
    ELSE 'Unknown'
  END as platform_name
FROM games
GROUP BY platform_id
ORDER BY platform_id;

-- 3. Sample Steam achievements to see what platform_id they're using
SELECT 
  a.platform_id,
  a.platform_game_id,
  g.name as game_name,
  COUNT(*) as achievement_count
FROM user_achievements ua
INNER JOIN achievements a ON a.platform_id = ua.platform_id
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
LEFT JOIN games g ON g.platform_id = a.platform_id
  AND g.platform_game_id = a.platform_game_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND a.platform_id NOT IN (1, 10, 11, 12)  -- Exclude PSN and Xbox
GROUP BY a.platform_id, a.platform_game_id, g.name
LIMIT 20;

-- 4. Check platforms table if it exists
SELECT * FROM platforms ORDER BY id;
