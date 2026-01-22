-- Migration 1012: Fix dashboard game sorting (ORDER BY last_played_at)
-- Simply add ORDER BY to the existing user_games view query

-- The user_games view already exists and works correctly
-- We just need the dashboard to sort by last_played_at

-- Check current function signature
SELECT 
  proname as function_name,
  pg_get_function_arguments(oid) as arguments,
  pg_get_functiondef(oid) as definition
FROM pg_proc 
WHERE proname = 'get_user_grouped_games';
