-- Find platinums added TODAY (Dec 29, 2025) after security fixes
-- User ID: 84b60ad6-cb2c-484f-8953-bf814551fd7a

SELECT 
    gt.name as game_name,
    a.name as achievement_name,
    ua.earned_at as earned_date,
    ua.created_at as added_to_db,
    ua.id as user_achievement_id,
    a.id as achievement_id,
    gt.id as game_title_id
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id
JOIN game_titles gt ON a.game_title_id = gt.id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
    AND a.is_platinum = true
    AND ua.created_at >= '2025-12-29 00:00:00'
ORDER BY ua.created_at DESC;
