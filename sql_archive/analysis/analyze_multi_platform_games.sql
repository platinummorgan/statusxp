-- ============================================
-- MULTI-PLATFORM GAME ANALYSIS
-- Identifies games that users own on multiple platforms
-- and how they're currently stored in user_games
-- ============================================

-- QUERY 1: Count users with multi-platform ownership
SELECT 
  'SUMMARY: Multi-Platform Ownership' as report_type,
  COUNT(DISTINCT ua.user_id) as affected_users,
  COUNT(DISTINCT a.game_title_id) as affected_games,
  COUNT(DISTINCT ua.user_id || '-' || a.game_title_id) as user_game_combinations
FROM user_achievements ua
JOIN achievements a ON a.id = ua.achievement_id
WHERE EXISTS (
  SELECT 1 FROM user_achievements ua2
  JOIN achievements a2 ON a2.id = ua2.achievement_id
  WHERE ua2.user_id = ua.user_id
    AND a2.game_title_id = a.game_title_id
    AND a2.platform != a.platform
);

-- QUERY 2: List all games that appear on multiple platforms
SELECT 
  gt.name as game_name,
  COUNT(DISTINCT a.platform) as platform_count,
  ARRAY_AGG(DISTINCT a.platform) as platforms,
  COUNT(DISTINCT ua.user_id) as users_with_multi_platform
FROM game_titles gt
JOIN achievements a ON a.game_title_id = gt.id
JOIN user_achievements ua ON ua.achievement_id = a.id
GROUP BY gt.id, gt.name
HAVING COUNT(DISTINCT a.platform) > 1
  AND EXISTS (
    -- Only show if at least one user owns it on multiple platforms
    SELECT 1 
    FROM user_achievements ua2
    JOIN achievements a2 ON a2.id = ua2.achievement_id
    WHERE a2.game_title_id = gt.id
    GROUP BY ua2.user_id
    HAVING COUNT(DISTINCT a2.platform) > 1
  )
ORDER BY users_with_multi_platform DESC, gt.name;

-- QUERY 3: Detailed breakdown by user
-- Shows which users own which games on multiple platforms
SELECT 
  p.psn_online_id,
  gt.name as game_name,
  ARRAY_AGG(DISTINCT a.platform ORDER BY a.platform) as platforms_owned,
  ug.platform_id as stored_platform_id,
  CASE ug.platform_id 
    WHEN 1 THEN 'PSN'
    WHEN 2 THEN 'Xbox'
    WHEN 3 THEN 'Steam'
    WHEN 5 THEN 'PS3'
    WHEN 11 THEN 'Unknown'
    ELSE 'Other'
  END as stored_platform_name,
  COUNT(DISTINCT a.platform) as platform_count,
  COUNT(ua.id) FILTER (WHERE a.platform = 'psn') as psn_achievements,
  COUNT(ua.id) FILTER (WHERE a.platform = 'xbox') as xbox_achievements,
  COUNT(ua.id) FILTER (WHERE a.platform = 'steam') as steam_achievements
FROM profiles p
JOIN user_achievements ua ON ua.user_id = p.id
JOIN achievements a ON a.id = ua.achievement_id
JOIN game_titles gt ON gt.id = a.game_title_id
LEFT JOIN user_games ug ON ug.user_id = p.id AND ug.game_title_id = gt.id
GROUP BY p.psn_online_id, gt.name, ug.platform_id, p.id, gt.id
HAVING COUNT(DISTINCT a.platform) > 1
ORDER BY p.psn_online_id, platform_count DESC, gt.name;

-- QUERY 4: Current user_games storage analysis
-- Shows how multi-platform games are currently represented
WITH multi_platform_users AS (
  SELECT DISTINCT ua.user_id, a.game_title_id
  FROM user_achievements ua
  JOIN achievements a ON a.id = ua.achievement_id
  GROUP BY ua.user_id, a.game_title_id
  HAVING COUNT(DISTINCT a.platform) > 1
)
SELECT 
  'STORAGE_ANALYSIS' as report_type,
  p.psn_online_id,
  gt.name as game_name,
  ug.platform_id as current_platform_id,
  CASE ug.platform_id 
    WHEN 1 THEN 'PSN'
    WHEN 2 THEN 'Xbox'
    WHEN 3 THEN 'Steam'
    WHEN 5 THEN 'PS3'
    ELSE 'Unknown'
  END as stored_as,
  ARRAY_AGG(DISTINCT a.platform) as actual_platforms,
  CASE 
    WHEN ug.platform_id = 1 AND 'psn' = ANY(ARRAY_AGG(DISTINCT a.platform)) THEN 'Correct'
    WHEN ug.platform_id = 2 AND 'xbox' = ANY(ARRAY_AGG(DISTINCT a.platform)) THEN 'Correct'
    WHEN ug.platform_id = 3 AND 'steam' = ANY(ARRAY_AGG(DISTINCT a.platform)) THEN 'Correct'
    ELSE 'Mismatch or Partial'
  END as storage_status
FROM multi_platform_users mpu
JOIN user_games ug ON ug.user_id = mpu.user_id AND ug.game_title_id = mpu.game_title_id
JOIN profiles p ON p.id = ug.user_id
JOIN game_titles gt ON gt.id = ug.game_title_id
JOIN user_achievements ua ON ua.user_id = mpu.user_id
JOIN achievements a ON a.id = ua.achievement_id AND a.game_title_id = mpu.game_title_id
GROUP BY p.psn_online_id, gt.name, ug.platform_id, p.id, gt.id
ORDER BY p.psn_online_id, gt.name;

-- QUERY 5: Platform distribution for multi-platform games
-- Which platform gets "picked" when user owns game on multiple platforms?
WITH multi_platform_games AS (
  SELECT ug.user_id, ug.game_title_id, ug.platform_id
  FROM user_games ug
  WHERE EXISTS (
    SELECT 1 FROM user_achievements ua
    JOIN achievements a ON a.id = ua.achievement_id
    WHERE ua.user_id = ug.user_id
      AND a.game_title_id = ug.game_title_id
    GROUP BY ua.user_id, a.game_title_id
    HAVING COUNT(DISTINCT a.platform) > 1
  )
)
SELECT 
  'PLATFORM_DISTRIBUTION' as report_type,
  mpg.platform_id,
  CASE mpg.platform_id 
    WHEN 1 THEN 'PSN'
    WHEN 2 THEN 'Xbox'
    WHEN 3 THEN 'Steam'
    WHEN 5 THEN 'PS3'
    WHEN 11 THEN 'Unknown'
  END as platform_name,
  COUNT(*) as user_games_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage
FROM multi_platform_games mpg
GROUP BY mpg.platform_id
ORDER BY user_games_count DESC;
