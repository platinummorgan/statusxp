-- Show ALL trophies for the LAST 5 synced games with earned status
WITH last_games AS (
    SELECT game_title_id 
    FROM user_games 
    WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
    ORDER BY updated_at DESC
    LIMIT 5
)
SELECT 
    gt.name AS game_name,
    t.name AS trophy_name,
    t.tier AS trophy_tier,
    t.description,
    t.sort_order,
    CASE 
        WHEN ut.earned_at IS NOT NULL THEN 'EARNED'
        ELSE 'NOT EARNED'
    END AS status,
    ut.earned_at
FROM trophies t
JOIN game_titles gt ON t.game_title_id = gt.id
LEFT JOIN user_trophies ut ON ut.trophy_id = t.id 
    AND ut.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
WHERE t.game_title_id IN (SELECT game_title_id FROM last_games)
ORDER BY gt.name, t.sort_order;
