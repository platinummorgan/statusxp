-- Check how many trophies now have rarity data
SELECT 
    COUNT(*) as total_trophies,
    COUNT(rarity_global) as with_rarity,
    COUNT(*) - COUNT(rarity_global) as missing_rarity,
    ROUND(100.0 * COUNT(rarity_global) / COUNT(*), 2) as percent_complete
FROM trophies;

-- Show a few platinum trophies with their rarity
SELECT 
    gt.name as game_name,
    t.rarity_global,
    t.psn_earn_rate,
    t.updated_at
FROM trophies t
JOIN game_titles gt ON t.game_title_id = gt.id
WHERE t.tier = 'platinum'
  AND t.rarity_global IS NOT NULL
ORDER BY t.rarity_global ASC
LIMIT 10;
