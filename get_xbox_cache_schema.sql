-- Get actual xbox_leaderboard_cache schema
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'xbox_leaderboard_cache' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- Get the data
SELECT *
FROM xbox_leaderboard_cache
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';
