-- Find Metal Gear Solid game
SELECT 
    gt.id,
    gt.name,
    gt.external_id,
    ug.bronze_trophies,
    ug.silver_trophies,
    ug.gold_trophies,
    ug.platinum_trophies,
    ug.updated_at
FROM game_titles gt
LEFT JOIN user_games ug ON ug.game_title_id = gt.id 
    AND ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
WHERE gt.name ILIKE '%Metal Gear%Solid%'
ORDER BY gt.name;
