-- Check achievements table structure
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'achievements' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check user_achievements table structure
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'user_achievements' 
  AND table_schema = 'public'
ORDER BY ordinal_position;
