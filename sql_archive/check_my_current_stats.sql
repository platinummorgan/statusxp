-- Check your actual current stats after cleanup
SELECT 
  COUNT(*) as total_games,
  SUM(CASE WHEN platform_id IN (1, 2, 5, 9) THEN 1 ELSE 0 END) as psn_games,
  SUM(CASE WHEN platform_id IN (10, 11, 12) THEN 1 ELSE 0 END) as xbox_games,
  SUM(CASE WHEN platform_id = 4 THEN 1 ELSE 0 END) as steam_games
FROM user_progress
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Check total achievements
SELECT 
  COUNT(*) as total_achievements
FROM user_achievements
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';
