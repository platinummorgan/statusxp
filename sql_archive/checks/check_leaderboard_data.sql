-- Check what the leaderboard query is actually returning
SELECT 
  user_id,
  display_name,
  avatar_url,
  gamerscore,
  achievement_count,
  total_games
FROM xbox_leaderboard_cache
ORDER BY gamerscore DESC NULLS LAST
LIMIT 10;
