-- Check The Crew 2 platinum trophy data
SELECT 
    gt.id as game_title_id,
    gt.name,
    ug.has_platinum,
    t.id as trophy_id,
    t.tier,
    t.rarity_global
FROM game_titles gt
JOIN user_games ug ON ug.game_title_id = gt.id
LEFT JOIN trophies t ON t.game_title_id = gt.id AND t.tier = 'platinum'
WHERE gt.name LIKE '%Crew%2%';
