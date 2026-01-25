-- Migration: Recalculate StatusXP for all users across all platforms
-- Purpose: Ensure PlayStation, Steam, and Xbox all have correct StatusXP calculated and displayed
-- Date: 2026-01-25
-- Impact: Updates user_progress.current_score for all users to reflect accurate StatusXP

BEGIN;

-- Step 1: Recalculate StatusXP for each user using calculate_statusxp_with_stacks
-- This function returns the correct statusxp_effective for each game/platform combination
DO $$
DECLARE
  v_user_id UUID;
  v_platform_id INT;
  v_platform_game_id TEXT;
  v_statusxp_effective NUMERIC;
BEGIN
  -- Get all unique users
  FOR v_user_id IN (SELECT DISTINCT user_id FROM user_progress ORDER BY user_id)
  LOOP
    -- For each user, recalculate StatusXP using the function
    FOR v_platform_id, v_platform_game_id, v_statusxp_effective IN
      SELECT 
        platform_id,
        platform_game_id,
        statusxp_effective
      FROM calculate_statusxp_with_stacks(v_user_id)
    LOOP
      -- Update user_progress with calculated StatusXP
      UPDATE user_progress
      SET current_score = v_statusxp_effective
      WHERE user_id = v_user_id
        AND platform_id = v_platform_id
        AND platform_game_id = v_platform_game_id;
    END LOOP;
    
    -- Log progress every 10 users
    IF (v_user_id::TEXT LIKE '%0') THEN
      RAISE NOTICE 'StatusXP recalculated for user: %', v_user_id;
    END IF;
  END LOOP;
END $$;

-- Step 2: Views auto-refresh when underlying data (user_progress, user_metadata) changes
-- No explicit refresh needed for xbox_leaderboard_cache or leaderboard_cache views
-- They will automatically reflect the new StatusXP values

COMMIT;

-- Verification queries (run after migration):
-- SELECT user_id, platform_id, platform_game_id, current_score FROM user_progress LIMIT 20;
-- SELECT display_name, gamerscore, total_statusxp FROM xbox_leaderboard_cache LIMIT 10;
