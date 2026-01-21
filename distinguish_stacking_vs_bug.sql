-- ============================================================================
-- Distinguish: Legitimate Stacking vs Backwards Compatibility Bug
-- ============================================================================
-- Check if multi-platform entries are from actual replay or sync duplication

-- Find games where user has progress on multiple Xbox platforms
-- and check if timestamps suggest legitimate replay or duplicate sync
WITH user_multi_platform_games AS (
  SELECT 
    up.user_id,
    up.platform_game_id,
    g.name,
    COUNT(DISTINCT up.platform_id) as platform_count,
    ARRAY_AGG(DISTINCT p.name ORDER BY p.id) as platforms,
    ARRAY_AGG(DISTINCT up.earned_at ORDER BY p.id) as sync_dates,
    MIN(up.earned_at) as first_sync,
    MAX(up.earned_at) as last_sync,
    MAX(up.earned_at) - MIN(up.earned_at) as time_between_platforms
  FROM user_achievements up
  JOIN games g ON g.platform_id = up.platform_id AND g.platform_game_id = up.platform_game_id
  JOIN platforms p ON p.id = up.platform_id
  WHERE up.platform_id IN (10, 11, 12)  -- Xbox platforms
  GROUP BY up.user_id, up.platform_game_id, g.name
  HAVING COUNT(DISTINCT up.platform_id) > 1
)
SELECT 
  *,
  CASE 
    WHEN time_between_platforms < INTERVAL '1 day' THEN 'LIKELY BUG - Same day sync'
    WHEN time_between_platforms < INTERVAL '7 days' THEN 'LIKELY BUG - Within a week'
    WHEN time_between_platforms < INTERVAL '30 days' THEN 'POSSIBLE BUG - Within a month'
    WHEN time_between_platforms >= INTERVAL '180 days' THEN 'LIKELY LEGITIMATE - 6+ months apart'
    ELSE 'UNCLEAR - Need manual review'
  END as classification
FROM user_multi_platform_games
ORDER BY time_between_platforms ASC, platform_count DESC
LIMIT 50;

-- Check user_achievements to see when achievements were actually earned
-- If all earned_at dates are the same, it's definitely a bug
SELECT 
  ua.user_id,
  ua.platform_game_id,
  g.name,
  ua.platform_id,
  p.name as platform_name,
  COUNT(*) as achievement_count,
  MIN(ua.earned_at) as first_achievement_date,
  MAX(ua.earned_at) as last_achievement_date,
  MAX(ua.earned_at) - MIN(ua.earned_at) as earning_timespan
FROM user_achievements ua
JOIN games g ON g.platform_id = ua.platform_id AND g.platform_game_id = ua.platform_game_id
JOIN platforms p ON p.id = ua.platform_id
WHERE ua.platform_id IN (10, 11, 12)
  AND ua.platform_game_id IN (
    -- Games that appear on multiple Xbox platforms for same user
    SELECT platform_game_id 
    FROM user_achievements 
    WHERE platform_id IN (10, 11, 12)
    GROUP BY user_id, platform_game_id
    HAVING COUNT(DISTINCT platform_id) > 1
    LIMIT 10
  )
GROUP BY ua.user_id, ua.platform_game_id, g.name, ua.platform_id, p.name
ORDER BY ua.user_id, ua.platform_game_id, ua.platform_id;

-- Check if games table duplicates match user data patterns
-- If game exists on 3 platforms but no user has achievements on all 3, likely a bug
SELECT 
  g.platform_game_id,
  g.name,
  COUNT(DISTINCT g.platform_id) as platforms_in_games_table,
  (SELECT COUNT(DISTINCT up.platform_id) 
   FROM user_achievements up 
   WHERE up.platform_game_id = g.platform_game_id 
     AND up.platform_id IN (10, 11, 12)) as platforms_with_user_data,
  (SELECT MAX(platform_count)
   FROM (
     SELECT COUNT(DISTINCT platform_id) as platform_count
     FROM user_achievements
     WHERE platform_game_id = g.platform_game_id
       AND platform_id IN (10, 11, 12)
     GROUP BY user_id
   ) sub) as max_platforms_per_user,
  CASE 
    WHEN (SELECT MAX(platform_count)
          FROM (
            SELECT COUNT(DISTINCT platform_id) as platform_count
            FROM user_achievements
            WHERE platform_game_id = g.platform_game_id
              AND platform_id IN (10, 11, 12)
            GROUP BY user_id
          ) sub) = 1 
    THEN 'LIKELY BUG - No user has it on multiple platforms'
    ELSE 'MIXED - Some users have multiple'
  END as assessment
FROM games g
WHERE g.platform_id IN (10, 11, 12)
GROUP BY g.platform_game_id, g.name
HAVING COUNT(DISTINCT g.platform_id) > 1
ORDER BY platforms_in_games_table DESC, g.name
LIMIT 30;
