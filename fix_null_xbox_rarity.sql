-- Fix NULL rarity Xbox achievements - set to COMMON as default
UPDATE achievements
SET 
  rarity_global = 50.0,  -- Default to 50% (COMMON)
  rarity_band = 'COMMON',
  rarity_multiplier = 1.00,
  base_status_xp = 0.50
WHERE rarity_global IS NULL
AND platform = 'xbox'
AND include_in_score = true;

-- Recalculate all affected user games
SELECT calculate_user_game_statusxp();

-- Refresh leaderboard
REFRESH MATERIALIZED VIEW CONCURRENTLY leaderboard_cache;

-- Verify the fix - check X_imThumper_X's new total
SELECT 
  'X_imThumper_X' as username,
  SUM(statusxp_effective) as new_total_statusxp,
  COUNT(*) as total_games
FROM user_games ug
JOIN profiles p ON p.id = ug.user_id
WHERE p.psn_online_id = 'X_imThumper_X';
