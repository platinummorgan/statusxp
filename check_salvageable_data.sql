-- Check what columns user_achievements actually has
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'user_achievements'
ORDER BY ordinal_position;

-- Check if we have ANY data for this user
SELECT COUNT(*) as total_rows,
       COUNT(DISTINCT platform_game_id) as unique_games
FROM user_achievements
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Sample a few rows to see what data exists
SELECT platform_id, platform_game_id, achievement_id, earned_date
FROM user_achievements
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
LIMIT 5;
