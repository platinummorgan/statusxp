-- Check game_titles table structure
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'game_titles'
ORDER BY ordinal_position;
