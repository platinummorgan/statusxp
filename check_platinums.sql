-- Query to list all platinum trophies for user
-- User ID: 84b60ad6-cb2c-484f-8953-bf814551fd7a

SELECT 
    gt.name as game_name,
    t.name as trophy_name,
    ut.earned_at,
    t.tier,
    ut.trophy_id,
    t.id as trophy_table_id
FROM user_trophies ut
JOIN trophies t ON ut.trophy_id = t.id
JOIN game_titles gt ON t.game_title_id = gt.id
WHERE ut.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
    AND t.tier = 'platinum'
ORDER BY ut.earned_at DESC;

-- Count platinums
SELECT COUNT(*) as platinum_count
FROM user_trophies ut
JOIN trophies t ON ut.trophy_id = t.id
WHERE ut.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
    AND t.tier = 'platinum';

-- Check for duplicates (same game with multiple platinums)
SELECT 
    gt.name as game_name,
    COUNT(*) as platinum_count,
    STRING_AGG(ut.earned_at::text, ', ' ORDER BY ut.earned_at) as earned_dates
FROM user_trophies ut
JOIN trophies t ON ut.trophy_id = t.id
JOIN game_titles gt ON t.game_title_id = gt.id
WHERE ut.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
    AND t.tier = 'platinum'
GROUP BY gt.name
HAVING COUNT(*) > 1
ORDER BY platinum_count DESC;
