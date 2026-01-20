-- Check all users on Xbox leaderboard after fix
SELECT 
  display_name,
  gamerscore,
  total_games,
  achievement_count
FROM xbox_leaderboard_cache
ORDER BY gamerscore DESC
LIMIT 20;
