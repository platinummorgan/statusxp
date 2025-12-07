-- Check if achievements table exists and has the right columns
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'achievements'
ORDER BY ordinal_position;
