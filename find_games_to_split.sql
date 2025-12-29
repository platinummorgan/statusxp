-- Find games that need to be split (multiple platform versions in one game_title)
-- These have user_games entries with different platform codes

SELECT 
    gt.id as game_title_id,
    gt.name as game_name,
    STRING_AGG(DISTINCT p.code, ', ') as platforms_used,
    COUNT(DISTINCT p.code) as platform_count,
    COUNT(DISTINCT ug.id) as user_game_entries,
    COUNT(DISTINCT a.id) as total_achievements
FROM game_titles gt
JOIN user_games ug ON ug.game_title_id = gt.id
JOIN platforms p ON ug.platform_id = p.id
JOIN achievements a ON a.game_title_id = gt.id
GROUP BY gt.id, gt.name
HAVING COUNT(DISTINCT p.code) > 1
ORDER BY platform_count DESC, user_game_entries DESC;
