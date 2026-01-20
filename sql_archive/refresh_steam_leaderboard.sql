-- Manual refresh of Steam leaderboard cache
-- Run this in Supabase SQL Editor if Steam leaderboard is not showing users

SELECT refresh_steam_leaderboard_cache();

-- Check if there are any entries
SELECT COUNT(*) as steam_leaderboard_entries FROM steam_leaderboard_cache;

-- Show first 10 entries to verify
SELECT * FROM steam_leaderboard_cache ORDER BY achievement_count DESC LIMIT 10;
