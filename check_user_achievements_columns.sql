-- Check the actual column names in user_achievements table
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'user_achievements'
ORDER BY ordinal_position;
