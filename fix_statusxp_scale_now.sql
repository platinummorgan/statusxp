-- Scale down all base_status_xp values to 0.5x (half the current values)
UPDATE achievements
SET base_status_xp = ROUND(base_status_xp * 0.5)
WHERE base_status_xp > 0;

-- Recalculate all user_games statusxp with new scaled values
SELECT calculate_user_game_statusxp();

-- Refresh leaderboard cache
REFRESH MATERIALIZED VIEW CONCURRENTLY leaderboard_cache;

-- Verify the change for Dex-Morgan
SELECT 
  COUNT(*) as total_games,
  SUM(statusxp_effective) as total_statusxp
FROM user_games ug
JOIN profiles p ON p.id = ug.user_id
WHERE p.psn_online_id = 'Dex-Morgan';
