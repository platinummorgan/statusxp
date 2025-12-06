-- Check Cloudpunk trophy count
SELECT COUNT(*) as total_trophies
FROM trophies t
JOIN game_titles gt ON t.game_title_id = gt.id
WHERE gt.name = 'Cloudpunk';

-- Check trophy groups
SELECT 
    gt.name AS game_name,
    t.psn_trophy_group_id,
    COUNT(*) as trophy_count
FROM trophies t
JOIN game_titles gt ON t.game_title_id = gt.id
WHERE gt.name = 'Cloudpunk'
GROUP BY gt.name, t.psn_trophy_group_id
ORDER BY t.psn_trophy_group_id;
