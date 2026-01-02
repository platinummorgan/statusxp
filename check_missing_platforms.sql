-- Check Bomb Rush Cyberfunk and Cloudpunk
SELECT 
    gt.id,
    gt.name,
    COUNT(a.id) as achievement_count,
    STRING_AGG(DISTINCT a.platform, ', ') as platforms
FROM game_titles gt
LEFT JOIN achievements a ON a.game_title_id = gt.id
WHERE gt.name ILIKE '%bomb rush%' OR gt.name ILIKE '%cloudpunk%'
GROUP BY gt.id, gt.name
ORDER BY gt.name;
