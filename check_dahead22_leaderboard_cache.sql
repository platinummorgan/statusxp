-- Check leaderboard cache for DaHead22
SELECT 
  user_id,
  display_name,
  platinum_count,
  total_games,
  updated_at
FROM psn_leaderboard_cache
WHERE display_name = 'DaHead22';

-- Also check the global leaderboard cache
SELECT 
  user_id,
  display_name,
  platinum_count,
  total_games,
  updated_at
FROM leaderboard_cache
WHERE display_name = 'DaHead22';
