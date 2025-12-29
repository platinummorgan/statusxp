-- Check if platinums exist for these games

SELECT 
    gt.name as game_name,
    p.code as platform_code,
    ug.has_platinum,
    a.id as platinum_achievement_id,
    a.name as platinum_name,
    a.platform_version,
    ua.id as user_has_it
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
JOIN platforms p ON ug.platform_id = p.id
LEFT JOIN achievements a ON a.game_title_id = gt.id AND a.is_platinum = true AND a.platform = 'psn'
LEFT JOIN user_achievements ua ON ua.user_id = ug.user_id AND ua.achievement_id = a.id
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
ORDER BY gt.name;
