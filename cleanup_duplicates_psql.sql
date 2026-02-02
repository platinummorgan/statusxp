-- Global cleanup of duplicate platform_game_ids
-- Keeps newest platform_id (PS5=1 > PS4=2 > PS3=5 > Vita=9)

-- Set no timeout
SET statement_timeout = 0;

BEGIN;

-- Delete old platform_id versions from user_achievements
DELETE FROM user_achievements
WHERE (user_id, platform_id, platform_game_id, platform_achievement_id) IN (
  SELECT 
    ua.user_id,
    ua.platform_id,
    ua.platform_game_id,
    ua.platform_achievement_id
  FROM user_achievements ua
  WHERE EXISTS (
    SELECT 1 
    FROM user_achievements ua2 
    WHERE ua2.user_id = ua.user_id 
      AND ua2.platform_game_id = ua.platform_game_id
      AND ua2.platform_id < ua.platform_id
    LIMIT 1
  )
);

-- Delete old platform_id versions from user_progress
DELETE FROM user_progress
WHERE (user_id, platform_id, platform_game_id) IN (
  SELECT 
    up.user_id,
    up.platform_id,
    up.platform_game_id
  FROM user_progress up
  WHERE EXISTS (
    SELECT 1 
    FROM user_progress up2 
    WHERE up2.user_id = up.user_id 
      AND up2.platform_game_id = up.platform_game_id
      AND up2.platform_id < up.platform_id
    LIMIT 1
  )
);

COMMIT;

-- Verify cleanup
SELECT COUNT(*) as remaining_duplicates
FROM (
  SELECT user_id, platform_game_id
  FROM user_achievements
  GROUP BY user_id, platform_game_id
  HAVING COUNT(DISTINCT platform_id) > 1
) dups;
