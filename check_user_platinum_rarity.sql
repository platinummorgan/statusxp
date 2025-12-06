-- Check platinum rarity for games in user_games
SELECT 
    gt.name as game_name,
    ug.has_platinum,
    t.rarity_global,
    t.psn_earn_rate
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
LEFT JOIN trophies t ON t.game_title_id = gt.id AND t.tier = 'platinum'
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND ug.has_platinum = true
ORDER BY t.rarity_global ASC NULLS LAST
LIMIT 20;
