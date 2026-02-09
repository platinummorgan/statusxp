-- Check actual user_games table structure
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'user_games'
ORDER BY ordinal_position;
