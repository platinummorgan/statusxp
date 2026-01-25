-- FIX ALL USERS: Update user_progress.current_score with calculated StatusXP
-- This fixes the bug where current_score was storing raw Gamerscore instead of StatusXP

-- Step 1: Get all unique user_ids
DO $$
DECLARE
  user_record RECORD;
  total_users INT;
  current_user_num INT := 0;
BEGIN
  -- Count total users
  SELECT COUNT(DISTINCT user_id) INTO total_users FROM user_progress;
  RAISE NOTICE 'Processing % users...', total_users;
  
  -- Loop through each user
  FOR user_record IN 
    SELECT DISTINCT user_id FROM user_progress
  LOOP
    current_user_num := current_user_num + 1;
    
    -- Update user_progress with calculated StatusXP
    UPDATE user_progress up
    SET current_score = cx.statusxp_effective
    FROM calculate_statusxp_with_stacks(user_record.user_id) cx
    WHERE up.user_id = user_record.user_id
      AND up.platform_id = cx.platform_id
      AND up.platform_game_id = cx.platform_game_id;
    
    -- Progress update every 10 users
    IF current_user_num % 10 = 0 THEN
      RAISE NOTICE 'Processed % / % users', current_user_num, total_users;
    END IF;
  END LOOP;
  
  RAISE NOTICE 'Completed updating current_score for all users';
END $$;

-- Step 2: Refresh leaderboard cache for all users
SELECT refresh_statusxp_leaderboard();

-- Step 3: Verify fix for sanders.geoff
SELECT 
  'sanders.geoff BEFORE (from leaderboard_cache - OLD)' as status,
  3179 as old_value;

SELECT 
  'sanders.geoff AFTER (calculated from user_progress - NEW)' as status,
  SUM(current_score) as new_value
FROM user_progress
WHERE user_id = 'ca9dc5a7-34a6-4a71-8659-d28da82de889';

SELECT 
  'sanders.geoff AFTER (from leaderboard_cache - REFRESHED)' as status,
  total_statusxp as refreshed_value
FROM leaderboard_cache
WHERE user_id = 'ca9dc5a7-34a6-4a71-8659-d28da82de889';
