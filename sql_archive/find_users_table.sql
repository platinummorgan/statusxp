-- Find the correct users table name
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name LIKE '%user%'
ORDER BY table_name;
