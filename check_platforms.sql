-- Check what platform data exists
SELECT DISTINCT 
    p.code as platform_code,
    COUNT(*) as game_count
FROM user_games ug
LEFT JOIN platforms p ON p.id = ug.platform_id
GROUP BY p.code
ORDER BY game_count DESC;

-- Sample games with platform info
SELECT 
    gt.name,
    p.code as platform,
    ug.platform_id
FROM user_games ug
JOIN game_titles gt ON gt.id = ug.game_title_id
LEFT JOIN platforms p ON p.id = ug.platform_id
LIMIT 10;
