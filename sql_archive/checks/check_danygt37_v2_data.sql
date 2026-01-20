-- Check if DanyGT37 has any data in v2 tables

-- Check user_progress_v2
SELECT 'user_progress_v2' as table_name, COUNT(*) as count
FROM user_progress_v2
WHERE user_id = '68de8222-9da5-4362-ac9b-96b302a7d455';

-- Check user_achievements_v2  
SELECT 'user_achievements_v2' as table_name, COUNT(*) as count
FROM user_achievements_v2
WHERE user_id = '68de8222-9da5-4362-ac9b-96b302a7d455';

-- Compare with old schema
SELECT 'user_games (old)' as table_name, COUNT(*) as count
FROM user_games
WHERE user_id = '68de8222-9da5-4362-ac9b-96b302a7d455';

SELECT 'user_achievements (old)' as table_name, COUNT(*) as count
FROM user_achievements
WHERE user_id = '68de8222-9da5-4362-ac9b-96b302a7d455';
