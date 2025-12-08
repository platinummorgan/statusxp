-- Find column names in game_titles table
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'game_titles' 
  AND table_schema = 'public'
ORDER BY ordinal_position;
