-- Find where total StatusXP is stored
SELECT column_name, data_type, table_name
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND (column_name LIKE '%statusxp%' OR column_name LIKE '%status_xp%')
ORDER BY table_name, column_name;

-- Check user_progress table structure
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'user_progress'
ORDER BY ordinal_position;
