-- Show ALL trophies for the last synced game (earned and unearned)
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
WHERE t.game_title_id = (
    SELECT game_title_id 
    FROM user_games 
    WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
    ORDER BY updated_at DESC 
    LIMIT 1
)
ORDER BY t.sort_order;
