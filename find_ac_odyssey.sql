-- Find Assassin's Creed Odyssey game_title_id
SELECT id as game_title_id, name
FROM game_titles
WHERE name ILIKE '%Assassin%Odyssey%'
OR name ILIKE '%Creed%Odyssey%';

-- Also check user_games for this game
SELECT ug.id as user_game_id, ug.game_title_id, gt.name, ug.platform_id, p.name as platform_name
FROM user_games ug
JOIN game_titles gt ON gt.id = ug.game_title_id
JOIN platforms p ON p.id = ug.platform_id
WHERE gt.name ILIKE '%Assassin%Odyssey%'
   OR gt.name ILIKE '%Creed%Odyssey%';
