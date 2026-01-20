-- Check if DanyGT37 is in PSN leaderboard cache
SELECT * FROM psn_leaderboard_cache 
WHERE user_id = '68de8222-9da5-4362-ac9b-96b302a7d455';

-- Refresh the cache to add them
SELECT refresh_psn_leaderboard_cache();

-- Verify they're now in the cache
SELECT * FROM psn_leaderboard_cache 
WHERE user_id = '68de8222-9da5-4362-ac9b-96b302a7d455';
