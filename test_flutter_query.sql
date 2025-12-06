-- Test the exact query the Flutter app is using
SELECT 
    ug.id,
    ug.has_platinum,
    gt.name,
    jsonb_agg(
        jsonb_build_object('tier', t.tier, 'rarity_global', t.rarity_global)
    ) as trophies
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
JOIN trophies t ON t.game_title_id = gt.id
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND ug.has_platinum = true
  AND t.tier = 'platinum'
GROUP BY ug.id, ug.has_platinum, gt.name
LIMIT 5;
