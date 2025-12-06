-- Test if we can get platinum trophy rarity
SELECT 
    gt.name as game_name,
    t.name as trophy_name,
    t.tier,
    t.rarity_global as platinum_rarity
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
LEFT JOIN trophies t ON t.game_title_id = gt.id AND t.tier = 'platinum'
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND ug.has_platinum = true
ORDER BY gt.name
LIMIT 5;
