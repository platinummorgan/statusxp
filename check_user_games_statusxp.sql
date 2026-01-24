-- Check if user_games has statusxp_earned populated correctly
SELECT 
    platform_id,
    COUNT(*) as game_count,
    SUM(statusxp_earned) as total_statusxp,
    AVG(statusxp_earned) as avg_statusxp_per_game
FROM user_games
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'your-email@example.com')
GROUP BY platform_id
ORDER BY platform_id;

-- Also check a few sample records
SELECT 
    platform_id,
    game_title,
    statusxp_earned,
    completion_percent,
    earned_trophies,
    total_trophies
FROM user_games
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'your-email@example.com')
LIMIT 20;
