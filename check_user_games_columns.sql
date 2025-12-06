-- Check all columns in user_games table
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'user_games' 
ORDER BY ordinal_position;
