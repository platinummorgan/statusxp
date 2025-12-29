-- Delete the incorrect platinum for "What Remains of Edith Finch"
-- User only has PS4 version (9 trophies, no plat) but got PS5 platinum "All Done"

-- First, find the user_achievement entry to delete
SELECT 
    ua.id,
    ua.user_id,
    ua.achievement_id,
    ua.earned_at,
    a.name as trophy_name,
    gt.name as game_name
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id
JOIN game_titles gt ON a.game_title_id = gt.id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
    AND ua.achievement_id = 66303;

-- Delete it
DELETE FROM user_achievements
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
    AND achievement_id = 66303;

-- Verify it's gone
SELECT COUNT(*) as remaining_platinums
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
    AND a.is_platinum = true;
