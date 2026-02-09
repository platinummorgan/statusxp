-- Check for data quality issues across all users

-- Issue 1: Games with achievements earned but total_achievements = 0
SELECT 
  'Games with earned achievements but total = 0' as issue,
  COUNT(*) as affected_entries,
  COUNT(DISTINCT user_id) as affected_users,
  COUNT(DISTINCT platform_id) as affected_platforms
FROM user_progress
WHERE achievements_earned > 0 AND total_achievements = 0;

-- Issue 2: Detailed breakdown by platform
SELECT 
  p.name as platform_name,
  COUNT(*) as broken_entries,
  COUNT(DISTINCT up.user_id) as affected_users,
  COUNT(DISTINCT up.platform_game_id) as affected_games
FROM user_progress up
JOIN platforms p ON p.id = up.platform_id
WHERE up.achievements_earned > 0 AND up.total_achievements = 0
GROUP BY p.name, up.platform_id
ORDER BY broken_entries DESC;

-- Issue 3: Sample of affected games
SELECT 
  up.user_id,
  g.name as game_name,
  p.name as platform_name,
  up.achievements_earned,
  up.total_achievements,
  up.completion_percentage
FROM user_progress up
JOIN games g ON g.platform_id = up.platform_id AND g.platform_game_id = up.platform_game_id
JOIN platforms p ON p.id = up.platform_id
WHERE up.achievements_earned > 0 AND up.total_achievements = 0
ORDER BY up.achievements_earned DESC
LIMIT 20;

-- Issue 4: Check if achievements table has the correct totals
SELECT 
  'Achievements table integrity check' as check_type,
  COUNT(*) as total_games,
  COUNT(DISTINCT platform_id) as platforms
FROM (
  SELECT 
    platform_id, 
    platform_game_id,
    COUNT(*) as achievement_count
  FROM achievements
  GROUP BY platform_id, platform_game_id
  HAVING COUNT(*) > 0
) subquery;

-- Issue 5: Cross-reference: user_progress with missing totals vs achievements table
SELECT 
  up.user_id,
  g.name,
  p.name as platform_name,
  up.achievements_earned as progress_earned,
  up.total_achievements as progress_total,
  COALESCE(a.actual_total, 0) as achievements_table_total
FROM user_progress up
JOIN games g ON g.platform_id = up.platform_id AND g.platform_game_id = up.platform_game_id
JOIN platforms p ON p.id = up.platform_id
LEFT JOIN (
  SELECT platform_id, platform_game_id, COUNT(*) as actual_total
  FROM achievements
  GROUP BY platform_id, platform_game_id
) a ON a.platform_id = up.platform_id AND a.platform_game_id = up.platform_game_id
WHERE up.achievements_earned > 0 AND up.total_achievements = 0
LIMIT 15;
