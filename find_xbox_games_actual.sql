-- Find how Xbox games are actually stored

-- Check all platform codes that exist
SELECT DISTINCT p.code, p.name, COUNT(*) as game_count
FROM user_games ug
JOIN platforms p ON ug.platform_id = p.id
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
GROUP BY p.code, p.name
ORDER BY game_count DESC;

-- Check for ANY games with xbox_current_gamerscore populated
SELECT 
    gt.name as game_name,
    p.code as platform_code,
    ug.xbox_current_gamerscore,
    ug.xbox_achievements_earned,
    ug.xbox_total_achievements
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
JOIN platforms p ON ug.platform_id = p.id
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
    AND ug.xbox_current_gamerscore IS NOT NULL
LIMIT 10;
