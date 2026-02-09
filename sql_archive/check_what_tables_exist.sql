-- Quick check: what tables exist?
SELECT tablename 
FROM pg_tables 
WHERE schemaname = 'public' 
  AND tablename LIKE '%game%'
ORDER BY tablename;
