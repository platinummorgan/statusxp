-- Get Cloudpunk's game_title_id and check trophy count
SELECT 
    gt.id as game_title_id,
    gt.name,
    COUNT(t.id) as trophy_count
FROM game_titles gt
LEFT JOIN trophies t ON t.game_title_id = gt.id
WHERE gt.name = 'Cloudpunk'
GROUP BY gt.id, gt.name;

-- Show all trophy IDs and names for Cloudpunk
SELECT 
    t.id,
    t.name,
    t.sort_order,
    t.game_title_id
FROM trophies t
JOIN game_titles gt ON t.game_title_id = gt.id
WHERE gt.name = 'Cloudpunk'
ORDER BY t.sort_order;
