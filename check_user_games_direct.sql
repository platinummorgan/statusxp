-- Check user_games table directly
SELECT * FROM user_games LIMIT 1;

-- Check what schema it's in
SELECT schemaname, tablename 
FROM pg_tables 
WHERE tablename = 'user_games';
