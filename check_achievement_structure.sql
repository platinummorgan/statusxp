-- Check how "What Remains of Edith Finch" achievements are structured

-- See how achievements link to game_titles and platform
SELECT 
    a.id,
    a.name,
    a.platform,
    a.psn_trophy_type,
    a.is_platinum,
    gt.id as game_title_id,
    gt.name as game_name
FROM achievements a
JOIN game_titles gt ON a.game_title_id = gt.id
WHERE gt.name LIKE '%Edith Finch%'
ORDER BY a.is_platinum DESC, a.name;

-- Check user_games entries for this game
SELECT 
    ug.id,
    gt.name,
    p.code as platform_code,
    p.name as platform_name,
    ug.total_trophies,
    ug.has_platinum
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
JOIN platforms p ON ug.platform_id = p.id
WHERE gt.name LIKE '%Edith Finch%'
    AND ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';
