-- AUDIT: Find all phantom platinums across all users
-- Phantom = user has platinum but user_games.has_platinum = false

SELECT 
    p.username,
    p.id as user_id,
    gt.name as game_name,
    ug.platform_id,
    pl.code as platform_code,
    ug.has_platinum as game_has_platinum,
    a.name as phantom_platinum_name,
    ua.earned_at
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id
JOIN game_titles gt ON a.game_title_id = gt.id
JOIN profiles p ON ua.user_id = p.id
LEFT JOIN user_games ug ON ug.user_id = ua.user_id 
    AND ug.game_title_id = gt.id
LEFT JOIN platforms pl ON ug.platform_id = pl.id
WHERE a.is_platinum = true
    AND (ug.has_platinum = false OR ug.has_platinum IS NULL)
ORDER BY p.username, gt.name;

-- Count phantom platinums per user
SELECT 
    p.username,
    COUNT(*) as phantom_platinum_count
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id
JOIN game_titles gt ON a.game_title_id = gt.id
JOIN profiles p ON ua.user_id = p.id
LEFT JOIN user_games ug ON ug.user_id = ua.user_id 
    AND ug.game_title_id = gt.id
WHERE a.is_platinum = true
    AND (ug.has_platinum = false OR ug.has_platinum IS NULL)
GROUP BY p.username
ORDER BY phantom_platinum_count DESC;

-- Total impact summary
SELECT 
    COUNT(DISTINCT ua.user_id) as affected_users,
    COUNT(*) as total_phantom_platinums
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id
JOIN game_titles gt ON a.game_title_id = gt.id
LEFT JOIN user_games ug ON ug.user_id = ua.user_id 
    AND ug.game_title_id = gt.id
WHERE a.is_platinum = true
    AND (ug.has_platinum = false OR ug.has_platinum IS NULL);
