-- Check platinum trophy rarity data
SELECT 
    gt.name,
    t.name as trophy_name,
    t.tier,
    t.rarity_global as platinum_rarity,
    ug.completion_percent,
    ug.bronze_trophies,
    ug.platinum_trophies
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
JOIN trophies t ON t.game_title_id = gt.id
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND t.tier = 'platinum'
  AND ug.has_platinum = true
ORDER BY ug.updated_at DESC
LIMIT 10;
