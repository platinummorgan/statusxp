-- Check which of the deleted platinums came back

SELECT 
    gt.name as game_name,
    p.code as platform_code,
    ug.has_platinum,
    COUNT(ua.id) as platinum_count_in_ua
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
JOIN platforms p ON ug.platform_id = p.id
LEFT JOIN user_achievements ua ON ua.user_id = ug.user_id
LEFT JOIN achievements a ON ua.achievement_id = a.id AND a.game_title_id = gt.id AND a.is_platinum = true
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
    AND ug.has_platinum = true
    AND gt.name IN (
        'A Plague Tale: Requiem',
        'Baldur''s Gate 3', 
        'Dragon''s Dogma: Dark Arisen',
        'FINAL FANTASY VII REMAKE',
        'God of War Ragnarök',
        'Red Dead Redemption 2',
        'Sekiro™: Shadows Die Twice',
        'Slender: The Arrival'
    )
GROUP BY gt.name, p.code, ug.has_platinum
ORDER BY gt.name;
