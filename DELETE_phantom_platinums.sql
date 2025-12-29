-- DELETE all phantom platinums
-- These are platinums where user_games.has_platinum = false or NULL

DELETE FROM user_achievements
WHERE id IN (
    SELECT ua.id
    FROM user_achievements ua
    JOIN achievements a ON ua.achievement_id = a.id
    JOIN game_titles gt ON a.game_title_id = gt.id
    LEFT JOIN user_games ug ON ug.user_id = ua.user_id 
        AND ug.game_title_id = gt.id
    WHERE a.is_platinum = true
        AND (ug.has_platinum = false OR ug.has_platinum IS NULL)
);

-- Verify cleanup
SELECT 
    COUNT(DISTINCT ua.user_id) as affected_users_remaining,
    COUNT(*) as phantom_platinums_remaining
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id
JOIN game_titles gt ON a.game_title_id = gt.id
LEFT JOIN user_games ug ON ug.user_id = ua.user_id 
    AND ug.game_title_id = gt.id
WHERE a.is_platinum = true
    AND (ug.has_platinum = false OR ug.has_platinum IS NULL);
