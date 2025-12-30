-- Check user_games columns for Xbox gamerscore
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'user_games' 
  AND column_name LIKE '%xbox%'
ORDER BY ordinal_position;
