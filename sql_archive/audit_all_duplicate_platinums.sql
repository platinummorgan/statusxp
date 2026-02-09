-- Find ALL users with duplicate platform_game_ids (same game on multiple platforms)
-- This shows how many users are affected by the duplicate platinum bug

WITH user_duplicates AS (
  SELECT 
    ua.user_id,
    ua.platform_game_id,
    COUNT(DISTINCT ua.platform_id) as platform_count,
    array_agg(ua.platform_id ORDER BY ua.platform_id) as platform_ids
  FROM user_achievements ua
  GROUP BY ua.user_id, ua.platform_game_id
  HAVING COUNT(DISTINCT ua.platform_id) > 1
),
platinum_duplicates AS (
  SELECT 
    ud.user_id,
    COUNT(*) as duplicate_games,
    AVG(array_length(ud.platform_ids, 1) - 1) as avg_extra_per_game
  FROM user_duplicates ud
  WHERE EXISTS (
    SELECT 1 FROM achievements a
    WHERE a.platform_game_id = ud.platform_game_id
      AND a.is_platinum = true
    LIMIT 1
  )
  GROUP BY ud.user_id
)
SELECT 
  user_id,
  duplicate_games,
  ROUND(duplicate_games * avg_extra_per_game) as extra_platinum_records
FROM platinum_duplicates
ORDER BY duplicate_games DESC;

-- Summary stats in separate query
WITH user_duplicates AS (
  SELECT 
    ua.user_id,
    ua.platform_game_id,
    COUNT(DISTINCT ua.platform_id) as platform_count,
    array_agg(ua.platform_id ORDER BY ua.platform_id) as platform_ids
  FROM user_achievements ua
  GROUP BY ua.user_id, ua.platform_game_id
  HAVING COUNT(DISTINCT ua.platform_id) > 1
)
SELECT 
  COUNT(DISTINCT ud.user_id) as total_affected_users,
  SUM(
    CASE 
      WHEN EXISTS (
        SELECT 1 FROM achievements a
        WHERE a.platform_game_id = ud.platform_game_id
          AND a.is_platinum = true
        LIMIT 1
      ) THEN 1 
      ELSE 0 
    END
  ) as total_duplicate_platinum_games,
  SUM(
    CASE 
      WHEN EXISTS (
        SELECT 1 FROM achievements a
        WHERE a.platform_game_id = ud.platform_game_id
          AND a.is_platinum = true
        LIMIT 1
      ) THEN array_length(ud.platform_ids, 1) - 1
      ELSE 0 
    END
  ) as total_extra_platinum_records
FROM user_duplicates ud;
