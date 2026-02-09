-- Check what columns exist in each cache table
-- Run in Supabase SQL Editor

-- Check PSN cache columns
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'psn_leaderboard_cache'
ORDER BY ordinal_position;

-- Check Xbox cache columns
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'xbox_leaderboard_cache'
ORDER BY ordinal_position;

-- Check Steam cache columns
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'steam_leaderboard_cache'
ORDER BY ordinal_position;

-- Check StatusXP cache columns
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'leaderboard_cache'
ORDER BY ordinal_position;
