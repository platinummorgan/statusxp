-- Migration: Cleanup duplicate platform_game_ids across all users
-- Keeps newest platform_id (PS5=1 > PS4=2 > PS3=5 > Vita=9)
-- This fixes the duplicate platinum bug affecting 5 users with 11,581 duplicate records

-- Set higher timeout for this migration
SET statement_timeout = '600s';

-- Delete old platform_id versions from user_achievements
-- Keep newest platform (lowest platform_id) when duplicates exist
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
      AND ua2.platform_id < ua.platform_id  -- Keep newer (lower platform_id)
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
