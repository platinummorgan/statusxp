-- Check if core tables still exist
SELECT schemaname, tablename 
FROM pg_tables 
WHERE schemaname IN ('public', 'auth')
ORDER BY schemaname, tablename;

-- Check if user data still exists
SELECT COUNT(*) as user_count FROM auth.users;

-- Check if your main app tables exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN ('profiles', 'achievements', 'trophies', 'games')
ORDER BY table_name;