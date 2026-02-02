-- Diagnose platinum count discrepancy
-- User claims 69 platinums but app shows 92
-- User ID: 68dd426c-3ce9-45e0-a9e6-70a9d3127eb8

-- Get user info
SELECT u.id, u.email, p.display_name
FROM auth.users u
LEFT JOIN profiles p ON p.id = u.id
WHERE u.id = '68dd426c-3ce9-45e0-a9e6-70a9d3127eb8';

-- Check actual platinum count from user_achievements
SELECT 
  COUNT(*) as total_platinums_in_user_achievements
FROM user_achievements ua
JOIN achievements a 
  ON a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id 
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = '68dd426c-3ce9-45e0-a9e6-70a9d3127eb8'
  AND a.is_platinum = true;

-- Check for duplicate platinum entries (same game on multiple platforms)
SELECT 
  g.name as game_name,
  g.platform_id,
  CASE g.platform_id
    WHEN 1 THEN 'PS5'
    WHEN 2 THEN 'PS4'
    WHEN 5 THEN 'PS3'
    WHEN 9 THEN 'PSVITA'
  END as platform_name,
  COUNT(*) as platinum_count,
  array_agg(a.platform_achievement_id) as achievement_ids
FROM user_achievements ua
JOIN achievements a 
  ON a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id 
  AND a.platform_achievement_id = ua.platform_achievement_id
JOIN games g 
  ON g.platform_id = ua.platform_id 
  AND g.platform_game_id = ua.platform_game_id
WHERE ua.user_id = '68dd426c-3ce9-45e0-a9e6-70a9d3127eb8'
  AND a.is_platinum = true
GROUP BY g.name, g.platform_id
ORDER BY g.name, g.platform_id;

-- Check if same game appears on multiple platforms (cross-gen stacking)
WITH platinum_games AS (
  SELECT 
    g.name as game_name,
    g.platform_id,
    g.platform_game_id,
    CASE g.platform_id
      WHEN 1 THEN 'PS5'
      WHEN 2 THEN 'PS4'
      WHEN 5 THEN 'PS3'
      WHEN 9 THEN 'PSVITA'
    END as platform_name
  FROM user_achievements ua
  JOIN achievements a 
    ON a.platform_id = ua.platform_id 
    AND a.platform_game_id = ua.platform_game_id 
    AND a.platform_achievement_id = ua.platform_achievement_id
  JOIN games g 
    ON g.platform_id = ua.platform_id 
    AND g.platform_game_id = ua.platform_game_id
  WHERE ua.user_id = '68dd426c-3ce9-45e0-a9e6-70a9d3127eb8'
    AND a.is_platinum = true
)
SELECT 
  game_name,
  COUNT(*) as platform_count,
  array_agg(platform_name ORDER BY platform_id) as platforms,
  array_agg(platform_game_id) as game_ids
FROM platinum_games
GROUP BY game_name
HAVING COUNT(*) > 1
ORDER BY platform_count DESC, game_name;

-- Check user_progress for platinum counts
SELECT 
  COUNT(*) as games_with_platinum_in_progress
FROM user_progress
WHERE user_id = '68dd426c-3ce9-45e0-a9e6-70a9d3127eb8'
  AND metadata->>'has_platinum' = 'true'
  AND (metadata->>'platinum_trophies')::int > 0;

-- List all platinums with game details
SELECT 
  g.name as game_name,
  CASE g.platform_id
    WHEN 1 THEN 'PS5'
    WHEN 2 THEN 'PS4'
    WHEN 5 THEN 'PS3'
    WHEN 9 THEN 'PSVITA'
  END as platform_name,
  a.name as trophy_name,
  ua.earned_at,
  g.platform_game_id,
  a.platform_achievement_id
FROM user_achievements ua
JOIN achievements a 
  ON a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id 
  AND a.platform_achievement_id = ua.platform_achievement_id
JOIN games g 
  ON g.platform_id = ua.platform_id 
  AND g.platform_game_id = ua.platform_game_id
WHERE ua.user_id = '68dd426c-3ce9-45e0-a9e6-70a9d3127eb8'
  AND a.is_platinum = true
ORDER BY ua.earned_at DESC NULLS LAST;
