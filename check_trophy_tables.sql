-- Check what trophy-related tables exist and have data
-- Check user_achievements (for Xbox/Steam)
SELECT 'user_achievements' as table_name, COUNT(*) as row_count
FROM user_achievements
WHERE user_id = 'b597a65e-2397-4b71-a3de-9c0b67ec1bf8';

-- Check if there's trophy earned data elsewhere
SELECT 
  COUNT(*) as total_games,
  SUM(earned_trophies) as total_earned_trophies
FROM user_games
WHERE user_id = 'b597a65e-2397-4b71-a3de-9c0b67ec1bf8';
