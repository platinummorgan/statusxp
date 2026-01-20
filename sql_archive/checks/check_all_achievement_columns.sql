-- Get ALL columns for achievements and trophies tables
SELECT 'achievements' as table_name, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'achievements'

UNION ALL

SELECT 'trophies' as table_name, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'trophies'

ORDER BY table_name, column_name;
