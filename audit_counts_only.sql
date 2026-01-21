-- ============================================================================
-- Quick Count Queries - Just paste the numbers back
-- ============================================================================

-- Query 1: How many PS4/PS5 duplicate games?
SELECT COUNT(*) as ps4_ps5_duplicate_games
FROM (
  SELECT DISTINCT g1.platform_game_id
  FROM games g1
  JOIN games g2 ON g1.platform_game_id = g2.platform_game_id
  WHERE g1.platform_id = 1 AND g2.platform_id = 2
) sub;

-- Query 2: How many Xbox duplicate games (360/One/Series)?
SELECT COUNT(*) as xbox_duplicate_games
FROM (
  SELECT platform_game_id
  FROM games
  WHERE platform_id IN (10, 11, 12)
  GROUP BY platform_game_id, name
  HAVING COUNT(DISTINCT platform_id) > 1
) sub;

-- Query 3: How many PS3/Vita duplicate games?
SELECT COUNT(*) as ps3_vita_duplicate_games
FROM (
  SELECT platform_game_id
  FROM games
  WHERE platform_id IN (3, 4)
  GROUP BY platform_game_id, name
  HAVING COUNT(DISTINCT platform_id) > 1
) sub;

-- Query 4: How many users have achievements on duplicate platforms?
SELECT COUNT(DISTINCT user_id) as users_with_duplicates
FROM user_achievements ua
JOIN games g ON ua.platform_id = g.platform_id 
  AND ua.platform_game_id = g.platform_game_id
WHERE g.platform_game_id IN (
  -- PS4/PS5 duplicates
  SELECT DISTINCT g1.platform_game_id
  FROM games g1
  JOIN games g2 ON g1.platform_game_id = g2.platform_game_id
  WHERE g1.platform_id = 1 AND g2.platform_id = 2
  UNION
  -- Xbox duplicates
  SELECT platform_game_id
  FROM games
  WHERE platform_id IN (10, 11, 12)
  GROUP BY platform_game_id
  HAVING COUNT(DISTINCT platform_id) > 1
);

-- Query 5: Of users with duplicates, how many look like bugs (same day) vs legitimate (months apart)?
WITH duplicate_games AS (
  SELECT DISTINCT g1.platform_game_id
  FROM games g1
  JOIN games g2 ON g1.platform_game_id = g2.platform_game_id
  WHERE (g1.platform_id = 1 AND g2.platform_id = 2)
     OR (g1.platform_id IN (10, 11, 12) AND g2.platform_id IN (10, 11, 12) AND g1.platform_id != g2.platform_id)
),
user_platforms AS (
  SELECT 
    ua.user_id,
    ua.platform_game_id,
    ua.platform_id,
    MIN(ua.earned_at) as first_earned,
    MAX(ua.earned_at) as last_earned
  FROM user_achievements ua
  WHERE ua.platform_game_id IN (SELECT platform_game_id FROM duplicate_games)
  GROUP BY ua.user_id, ua.platform_game_id, ua.platform_id
),
user_analysis AS (
  SELECT 
    user_id,
    platform_game_id,
    COUNT(DISTINCT platform_id) as platform_count,
    MAX(last_earned) - MIN(first_earned) as time_between_platforms
  FROM user_platforms
  GROUP BY user_id, platform_game_id
  HAVING COUNT(DISTINCT platform_id) > 1
)
SELECT 
  COUNT(*) FILTER (WHERE time_between_platforms < INTERVAL '7 days') as likely_bugs,
  COUNT(*) FILTER (WHERE time_between_platforms >= INTERVAL '180 days') as likely_legitimate,
  COUNT(*) FILTER (WHERE time_between_platforms >= INTERVAL '7 days' AND time_between_platforms < INTERVAL '180 days') as unclear,
  COUNT(*) as total_users_with_multi_platform
FROM user_analysis;
