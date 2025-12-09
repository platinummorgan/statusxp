-- Find which tables have achievement/trophy data
SELECT 'user_games' as table_name, 
       COUNT(*) as total_rows,
       SUM(earned_trophies) as total_earned
FROM user_games
WHERE user_id = 'b597a65e-2397-4b71-a3de-9c0b67ec1bf8'

UNION ALL

SELECT 'user_achievements' as table_name,
       COUNT(*) as total_rows,
       COUNT(CASE WHEN earned_at IS NOT NULL THEN 1 END) as with_timestamps
FROM user_achievements  
WHERE user_id = 'b597a65e-2397-4b71-a3de-9c0b67ec1bf8'

UNION ALL

SELECT 'user_trophies' as table_name,
       COUNT(*) as total_rows,
       COUNT(CASE WHEN earned_at IS NOT NULL THEN 1 END) as with_timestamps
FROM user_trophies
WHERE user_id = 'b597a65e-2397-4b71-a3de-9c0b67ec1bf8';

-- Check if user_achievements table even exists and what columns it has
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'user_achievements'
ORDER BY ordinal_position;
