-- Check which games have platinums but no rarity data
SELECT 
    gt.id,
    gt.name,
    ug.has_platinum,
    t.rarity_global
FROM game_titles gt
JOIN user_games ug ON ug.game_title_id = gt.id
LEFT JOIN trophies t ON t.game_title_id = gt.id AND t.tier = 'platinum'
WHERE ug.has_platinum = true
  AND (t.rarity_global IS NULL OR t.id IS NULL)
ORDER BY gt.name;
