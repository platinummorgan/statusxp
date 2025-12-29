-- Check which version of "What Remains of Edith Finch" user has
-- PS4 = no platinum, PS5 = has platinum "All Done"

SELECT 
    ug.id,
    gt.name as game_name,
    p.name as platform_name,
    p.code as platform_code,
    ug.has_platinum,
    ug.earned_trophies,
    ug.total_trophies
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
JOIN platforms p ON ug.platform_id = p.id
WHERE gt.name LIKE '%Edith Finch%'
    AND ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Also check what platform the achievement is marked as
SELECT 
    a.id,
    a.name,
    a.platform,
    gt.name as game_name,
    ua.earned_at
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id  
JOIN game_titles gt ON a.game_title_id = gt.id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
    AND gt.name LIKE '%Edith Finch%'
    AND a.is_platinum = true;
