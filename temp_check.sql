SELECT 
  tablename,
  schemaname
FROM pg_tables 
WHERE tablename = 'user_premium_status';
