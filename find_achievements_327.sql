-- Find ALL achievements/trophies for game_title_id 327
SELECT 'achievements' as source_table, COUNT(*) as count
FROM achievements
WHERE game_title_id = 327

UNION ALL

SELECT 'trophies' as source_table, COUNT(*) as count
FROM trophies
WHERE game_title_id = 327;

-- Show actual column names in achievements table
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'achievements' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- Show actual column names in trophies table
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'trophies' 
  AND table_schema = 'public'
ORDER BY ordinal_position;
