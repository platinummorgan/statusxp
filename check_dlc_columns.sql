SELECT 
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'achievements'
  AND column_name IN ('is_dlc', 'dlc_name')
ORDER BY ordinal_position;
