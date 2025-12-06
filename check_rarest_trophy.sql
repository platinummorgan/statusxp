-- Check what's in rarest_trophy_rarity column
SELECT 
    gt.name,
    ug.rarest_trophy_rarity,
    ug.completion_percent,
    ug.has_platinum
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
ORDER BY ug.updated_at DESC
LIMIT 10;
