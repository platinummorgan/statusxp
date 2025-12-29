-- Get actual Xbox games and total gamerscore

SELECT 
    gt.name as game_name,
    ug.xbox_current_gamerscore,
    ug.xbox_max_gamerscore,
    ug.xbox_achievements_earned,
    ug.xbox_total_achievements
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
JOIN platforms p ON ug.platform_id = p.id
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
    AND p.code = 'XBOXONE'
ORDER BY ug.xbox_current_gamerscore DESC
LIMIT 10;

-- Total Xbox gamerscore
SELECT 
    SUM(ug.xbox_current_gamerscore) as total_gamerscore,
    SUM(ug.xbox_max_gamerscore) as max_possible_gamerscore,
    SUM(ug.xbox_achievements_earned) as total_achievements,
    COUNT(*) as xbox_game_count
FROM user_games ug
JOIN platforms p ON ug.platform_id = p.id
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
    AND p.code = 'XBOXONE';
