-- Check if gamerscore column exists and has proper permissions
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'xbox_leaderboard_cache'
ORDER BY ordinal_position;

-- Check RLS policies on the table
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'xbox_leaderboard_cache';

-- Test what an authenticated user would see (simulating app query)
SELECT user_id, display_name, gamerscore, achievement_count
FROM xbox_leaderboard_cache
ORDER BY gamerscore DESC
LIMIT 5;
