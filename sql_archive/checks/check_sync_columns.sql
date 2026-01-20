-- Check actual sync-related column names in profiles table
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'profiles' 
  AND (column_name LIKE '%sync%' OR column_name LIKE '%steam%' OR column_name LIKE '%psn%')
ORDER BY column_name;
