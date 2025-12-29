-- Find duplicate platinums in user_achievements
-- User ID: 84b60ad6-cb2c-484f-8953-bf814551fd7a

-- List all platinums
SELECT 
    gt.name as game_name,
    a.name as achievement_name,
    ua.earned_at,
    a.id as achievement_id,
    a.platform
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id
JOIN game_titles gt ON a.game_title_id = gt.id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
    AND a.is_platinum = true
ORDER BY ua.earned_at DESC;

-- Find games with multiple platinums
SELECT 
    gt.name as game_name,
    COUNT(*) as platinum_count,
    STRING_AGG(ua.earned_at::text, ' | ' ORDER BY ua.earned_at) as earned_dates,
    STRING_AGG(a.platform, ', ') as platforms
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id
JOIN game_titles gt ON a.game_title_id = gt.id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
    AND a.is_platinum = true
GROUP BY gt.name
HAVING COUNT(*) > 1
ORDER BY platinum_count DESC;
