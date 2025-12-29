-- Check if there are multiple "What Remains of Edith Finch" game entries
-- PS4 version vs PS5 version

SELECT 
    gt.id,
    gt.name,
    COUNT(a.id) as trophy_count,
    COUNT(CASE WHEN a.is_platinum = true THEN 1 END) as platinum_count
FROM game_titles gt
LEFT JOIN achievements a ON a.game_title_id = gt.id AND a.platform = 'psn'
WHERE gt.name LIKE '%Edith Finch%'
GROUP BY gt.id, gt.name;

-- Check which version YOU have in user_games
SELECT 
    ug.game_title_id,
    gt.name,
    ug.total_trophies,
    ug.has_platinum
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
WHERE gt.name LIKE '%Edith Finch%'
    AND ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Check which version the "All Done" platinum belongs to
SELECT 
    a.id,
    a.game_title_id,
    gt.name,
    a.name as trophy_name,
    COUNT(*) OVER (PARTITION BY a.game_title_id) as total_trophies_for_game
FROM achievements a
JOIN game_titles gt ON a.game_title_id = gt.id
WHERE a.id = 66303;
