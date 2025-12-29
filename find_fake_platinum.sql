-- Find the incorrectly marked platinum in "What Remains of Edith Finch"
-- This game doesn't have a platinum but one achievement is marked as such

SELECT 
    a.id,
    a.name,
    a.psn_trophy_type,
    a.is_platinum,
    a.platform,
    gt.name as game_name
FROM achievements a
JOIN game_titles gt ON a.game_title_id = gt.id
WHERE gt.name LIKE '%Edith Finch%'
    AND a.is_platinum = true;

-- Show all achievements for this game
SELECT 
    a.id,
    a.name,
    a.psn_trophy_type,
    a.is_platinum,
    a.platform
FROM achievements a
JOIN game_titles gt ON a.game_title_id = gt.id
WHERE gt.name LIKE '%Edith Finch%'
ORDER BY a.id;
