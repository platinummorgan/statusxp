-- Check if the 11-11: Memories Retold platinum trophy now has rarity data
SELECT 
    gt.name as game_name,
    t.name as trophy_name,
    t.tier,
    t.rarity_global,
    t.psn_earn_rate,
    t.psn_trophy_id,
    t.updated_at
FROM trophies t
JOIN game_titles gt ON t.game_title_id = gt.id
WHERE gt.name LIKE '%11-11%'
  AND t.tier = 'platinum';
