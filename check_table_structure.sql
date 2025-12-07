-- Check what columns exist in user_trophies
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'user_trophies'
ORDER BY ordinal_position;

-- Check what columns exist in trophies table
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'trophies'
ORDER BY ordinal_position;

-- Simple count of ALL records in user_trophies for this user
SELECT COUNT(*) as total_trophies_old_table
FROM user_trophies
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';
