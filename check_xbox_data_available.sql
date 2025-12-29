-- Check what Xbox data is actually stored in the database
-- User ID: 84b60ad6-cb2c-484f-8953-bf814551fd7a

-- Check user_games for Xbox - what fields do we populate?
SELECT 
    gt.name as game_name,
    ug.xbox_current_gamerscore,
    ug.xbox_max_gamerscore,
    ug.xbox_total_achievements,
    ug.xbox_achievements_earned
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
JOIN platforms p ON ug.platform_id = p.id
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
    AND p.code LIKE '%xbox%'
ORDER BY ug.xbox_current_gamerscore DESC NULLS LAST
LIMIT 10;

-- Check achievements table - do we store gamerscore?
SELECT 
    a.id,
    a.name,
    a.xbox_gamerscore,
    gt.name as game_name
FROM achievements a
JOIN game_titles gt ON a.game_title_id = gt.id
WHERE a.platform = 'xbox'
    AND a.xbox_gamerscore IS NOT NULL
LIMIT 10;

-- Check if we're tracking total gamerscore anywhere
SELECT 
    SUM(ug.xbox_current_gamerscore) as total_gamerscore,
    COUNT(*) as xbox_games
FROM user_games ug
JOIN platforms p ON ug.platform_id = p.id
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
    AND p.code LIKE '%xbox%';
