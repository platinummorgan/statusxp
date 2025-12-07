-- Check the actual columns in trophies table
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'trophies'
ORDER BY ordinal_position;
