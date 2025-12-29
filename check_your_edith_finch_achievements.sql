-- Check what Edith Finch achievements YOU have in user_achievements

SELECT 
    ua.id,
    ua.earned_at,
    a.name,
    a.psn_trophy_type,
    a.is_platinum
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id
JOIN game_titles gt ON a.game_title_id = gt.id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
    AND gt.name LIKE '%Edith Finch%'
ORDER BY a.is_platinum DESC, a.name;
