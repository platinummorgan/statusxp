-- Manual fix for Robo Ripper's StatusXP
-- This recalculates current_score with proper StatusXP values

-- Step 1: Calculate StatusXP per game
WITH calculated_xp AS (
  SELECT *
  FROM calculate_statusxp_with_stacks((SELECT id FROM profiles WHERE username = 'Robo Ripper'))
)
-- Step 2: Update user_progress.current_score with calculated values
UPDATE user_progress up
SET current_score = cx.statusxp_effective
FROM calculated_xp cx
WHERE up.user_id = (SELECT id FROM profiles WHERE username = 'Robo Ripper')
  AND up.platform_id = cx.platform_id
  AND up.platform_game_id = cx.platform_game_id;

-- Step 3: Refresh leaderboard cache
SELECT refresh_statusxp_leaderboard();

-- Step 4: Verify the fix
SELECT 
  total_statusxp,
  total_game_entries
FROM leaderboard_cache
WHERE user_id = (SELECT id FROM profiles WHERE username = 'Robo Ripper');
