-- Check actual user_achievements schema
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'user_achievements'
ORDER BY ordinal_position;
