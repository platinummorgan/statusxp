-- Check what columns exist in leaderboard_cache
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'leaderboard_cache';

-- Check what columns exist in psn_leaderboard_cache
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'psn_leaderboard_cache';
