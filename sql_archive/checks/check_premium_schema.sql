-- Check actual schema of user_premium_status table
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'user_premium_status';
