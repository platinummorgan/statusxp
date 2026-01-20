-- Check actual columns in achievements and trophies tables
SELECT 
  'achievements' as table_name,
  column_name,
  data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'achievements'
  AND (column_name LIKE '%achievement%' OR column_name LIKE '%xbox%' OR column_name LIKE '%steam%' OR column_name LIKE '%id%')

UNION ALL

SELECT 
  'trophies' as table_name,
  column_name,
  data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'trophies'
  AND (column_name LIKE '%trophy%' OR column_name LIKE '%psn%' OR column_name LIKE '%id%')
  
ORDER BY table_name, column_name;
