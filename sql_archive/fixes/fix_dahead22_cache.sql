-- Refresh leaderboard cache for DaHead22 to match actual data (6 platinums)
-- This will force the cache to recalculate from user_games

-- First, let's see the user_id
SELECT id, psn_online_id FROM profiles WHERE psn_online_id = 'DaHead22';

-- Now manually refresh just this user's cache entry
-- Delete the old cache entry
DELETE FROM psn_leaderboard_cache 
WHERE user_id = '3c5206fb-6806-4f95-80d6-29ee7e974be9';

-- Force a refresh by calling the function
SELECT refresh_psn_leaderboard_cache();
