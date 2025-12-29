-- Full list of all platinums for manual review
-- User ID: 84b60ad6-cb2c-484f-8953-bf814551fd7a

SELECT 
    ROW_NUMBER() OVER (ORDER BY ua.earned_at DESC) as "#",
    gt.name as "Game",
    ua.earned_at as "Earned Date",
    ua.id as "DB Record ID"
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id
JOIN game_titles gt ON a.game_title_id = gt.id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
    AND a.is_platinum = true
ORDER BY ua.earned_at DESC;
