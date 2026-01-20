-- Check user_games table structure
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'user_games' 
  AND table_schema = 'public'
ORDER BY ordinal_position;
