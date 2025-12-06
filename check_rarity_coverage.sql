-- Check how many trophies have rarity vs how many don't
SELECT 
    COUNT(*) as total_trophies,
    COUNT(rarity_global) as with_rarity,
    COUNT(*) - COUNT(rarity_global) as missing_rarity,
    ROUND(100.0 * COUNT(rarity_global) / COUNT(*), 2) as percent_complete
FROM trophies;

-- Show breakdown by tier
SELECT 
    tier,
    COUNT(*) as total,
    COUNT(rarity_global) as with_rarity,
    COUNT(*) - COUNT(rarity_global) as missing_rarity
FROM trophies
GROUP BY tier
ORDER BY tier;
