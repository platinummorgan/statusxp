-- Quick check: what columns exist in game_titles for URLs?
SELECT 
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'game_titles'
  AND column_name LIKE '%url%'
ORDER BY ordinal_position;
