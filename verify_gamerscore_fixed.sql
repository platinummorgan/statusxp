-- Verify xbox_leaderboard_cache now shows correct gamerscore
SELECT 
  display_name,
  gamerscore,
  achievement_count,
  total_games
FROM xbox_leaderboard_cache
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';
