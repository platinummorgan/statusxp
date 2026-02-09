-- ============================================================================
-- CRITICAL: Check if users are getting duplicate credit for same game
-- ============================================================================
-- Check if playing one Xbox game is giving credit for multiple platforms

-- Test case: Check PROTOTYPE achievements across platforms
SELECT 
  'PROTOTYPE Analysis' as analysis,
  platform_id,
  p.name as platform_name,
  COUNT(DISTINCT platform_game_id) as unique_game_ids,
  COUNT(*) as total_game_entries
FROM games g
JOIN platforms p ON p.id = g.platform_id
WHERE g.name ILIKE '%PROTOTYPE%'
  AND g.platform_id IN (10, 11, 12)
GROUP BY platform_id, p.name;

-- Check if any user has achievements for PROTOTYPE on multiple Xbox platforms
-- (This would indicate duplicate credit)
SELECT 
  ua.user_id,
  COUNT(DISTINCT ua.platform_id) as platforms_with_achievements,
  STRING_AGG(DISTINCT p.name, ', ' ORDER BY p.name) as platforms,
  COUNT(DISTINCT ua.platform_achievement_id) as total_achievements
FROM user_achievements ua
JOIN platforms p ON p.id = ua.platform_id
WHERE ua.platform_game_id = '1096157262'  -- PROTOTYPE game ID
  AND ua.platform_id IN (10, 11, 12)
GROUP BY ua.user_id
HAVING COUNT(DISTINCT ua.platform_id) > 1;

-- Check user_achievements for duplicate platform entries for same game
SELECT 
  up.user_id,
  up.platform_game_id,
  STRING_AGG(DISTINCT p.name, ', ' ORDER BY p.name) as platforms,
  COUNT(DISTINCT up.platform_id) as platform_count,
  COUNT(DISTINCT up.platform_achievement_id) as total_achievements_across_platforms
FROM user_achievements up
JOIN platforms p ON p.id = up.platform_id
WHERE up.platform_id IN (10, 11, 12)  -- Xbox platforms
GROUP BY up.user_id, up.platform_game_id
HAVING COUNT(DISTINCT up.platform_id) > 1  -- Same game on multiple platforms
ORDER BY total_achievements_across_platforms DESC
LIMIT 20;

-- Check how leaderboard calculation is counting these
-- Get total StatusXP for users who have Xbox games
SELECT 
  up.user_id,
  COUNT(DISTINCT CONCAT(up.platform_id, '-', up.platform_game_id)) as unique_game_entries,
  COUNT(DISTINCT up.platform_game_id) as unique_game_ids,
  COUNT(DISTINCT up.platform_achievement_id) as total_achievements,
  CASE 
    WHEN COUNT(DISTINCT CONCAT(up.platform_id, '-', up.platform_game_id)) > COUNT(DISTINCT up.platform_game_id)
    THEN 'DUPLICATE CREDIT DETECTED'
    ELSE 'OK'
  END as status
FROM user_achievements up
WHERE up.platform_id IN (10, 11, 12)
GROUP BY up.user_id
HAVING COUNT(DISTINCT CONCAT(up.platform_id, '-', up.platform_game_id)) > COUNT(DISTINCT up.platform_game_id)
ORDER BY total_achievements DESC
LIMIT 20;

-- Check for specific games where this is happening
SELECT 
  g.name,
  g.platform_game_id,
  COUNT(DISTINCT g.platform_id) as platform_count,
  STRING_AGG(DISTINCT p.name, ', ' ORDER BY p.name) as platforms,
  (SELECT COUNT(DISTINCT user_id) 
   FROM user_achievements 
   WHERE platform_game_id = g.platform_game_id 
     AND platform_id IN (10, 11, 12)) as users_affected
FROM games g
JOIN platforms p ON p.id = g.platform_id
WHERE g.platform_id IN (10, 11, 12)
GROUP BY g.name, g.platform_game_id
HAVING COUNT(DISTINCT g.platform_id) > 1
ORDER BY users_affected DESC
LIMIT 30;
