-- Force these games to re-sync by clearing last_rarity_sync
-- This will make sync think they need a rarity refresh and re-process all trophies

UPDATE user_games ug
SET last_rarity_sync = NULL
FROM game_titles gt, platforms p
WHERE ug.game_title_id = gt.id
    AND ug.platform_id = p.id
    AND ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
    AND gt.name IN (
        'A Plague Tale: Requiem',
        'Baldur''s Gate 3', 
        'Dragon''s Dogma: Dark Arisen',
        'FINAL FANTASY VII REMAKE',
        'God of War Ragnarök',
        'Red Dead Redemption 2',
        'Sekiro™: Shadows Die Twice',
        'Slender: The Arrival'
    );

-- Verify
SELECT gt.name, p.code, ug.last_rarity_sync
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
JOIN platforms p ON ug.platform_id = p.id
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
    AND gt.name IN (
        'A Plague Tale: Requiem',
        'Baldur''s Gate 3', 
        'Dragon''s Dogma: Dark Arisen',
        'FINAL FANTASY VII REMAKE',
        'God of War Ragnarök',
        'Red Dead Redemption 2',
        'Sekiro™: Shadows Die Twice',
        'Slender: The Arrival'
    );
