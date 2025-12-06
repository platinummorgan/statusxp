-- Count how many platinum trophies have rarity now
SELECT 
    COUNT(*) as total_platinum_trophies,
    COUNT(rarity_global) as with_rarity,
    COUNT(*) - COUNT(rarity_global) as missing_rarity
FROM trophies
WHERE tier = 'platinum';

-- Show recently updated platinum trophies
SELECT 
    gt.name as game_name,
    t.rarity_global,
    t.updated_at
FROM trophies t
JOIN game_titles gt ON t.game_title_id = gt.id
WHERE t.tier = 'platinum'
ORDER BY t.updated_at DESC
LIMIT 10;
