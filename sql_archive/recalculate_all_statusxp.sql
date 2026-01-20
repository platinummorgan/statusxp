-- Recalculate ALL user_games with the correct (current) base_status_xp values
-- This will fix everyone's StatusXP to use the new scale

-- Call the recalculation function
SELECT calculate_user_game_statusxp();

-- Refresh the leaderboard cache
REFRESH MATERIALIZED VIEW CONCURRENTLY leaderboard_cache;

-- Verify Dex-Morgan's new total
SELECT 
  COUNT(*) as total_games,
  SUM(statusxp_effective) as total_statusxp,
  SUM(statusxp_effective) / 2.0 as approximate_old_value
FROM user_games ug
JOIN profiles p ON p.id = ug.user_id
WHERE p.psn_online_id = 'Dex-Morgan';
