-- Test platform leaderboard caches exist and work
-- Run in Supabase SQL Editor

-- Check if steam_leaderboard_cache exists
SELECT COUNT(*) as steam_count FROM steam_leaderboard_cache;

-- Check if xbox_leaderboard_cache exists  
SELECT COUNT(*) as xbox_count FROM xbox_leaderboard_cache;

-- Check psn cache (materialized view)
SELECT COUNT(*) as psn_count FROM psn_leaderboard_cache;

-- Test the RPC functions
SELECT * FROM get_psn_leaderboard_with_movement(5, 0);
SELECT * FROM get_xbox_leaderboard_with_movement(5, 0);
SELECT * FROM get_steam_leaderboard_with_movement(5, 0);
