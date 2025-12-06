-- Check if trophyEarnedRate is being saved to any field
SELECT 
    gt.name as game_name,
    t.name as trophy_name,
    t.tier,
    t.rarity_global,
    t.psn_earn_rate,
    t.icon_url IS NOT NULL as has_icon
FROM trophies t
JOIN game_titles gt ON t.game_title_id = gt.id
WHERE t.tier = 'platinum'
  AND gt.id IN (
    SELECT game_title_id 
    FROM user_games 
    WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a' 
    AND has_platinum = true
  )
LIMIT 5;
