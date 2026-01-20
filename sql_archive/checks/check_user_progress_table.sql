-- Check if user_progress table exists and has data

-- 1. Does user_progress table exist?
SELECT COUNT(*) as total_rows
FROM user_progress
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- 2. What tables DO exist?
SELECT tablename 
FROM pg_tables 
WHERE schemaname = 'public' 
  AND tablename LIKE '%user%'
ORDER BY tablename;
