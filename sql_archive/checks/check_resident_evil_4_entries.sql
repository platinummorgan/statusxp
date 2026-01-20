-- Find all Resident Evil 4 game entries (original vs remake)

SELECT 
    gt.id as game_title_id,
    gt.name,
    gt.created_at,
    COUNT(DISTINCT a.platform) as platform_count,
    ARRAY_AGG(DISTINCT a.platform) as platforms,
    COUNT(a.id) as achievement_count,
    SUM(CASE WHEN a.psn_trophy_type = 'platinum' THEN 1 ELSE 0 END) as has_platinum
FROM game_titles gt
LEFT JOIN achievements a ON a.game_title_id = gt.id
WHERE gt.name ILIKE '%resident evil 4%'
GROUP BY gt.id, gt.name, gt.created_at
ORDER BY gt.created_at;
