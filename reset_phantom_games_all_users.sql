-- Reset last_rarity_sync for games that had phantom platinums
-- This will force them to re-sync and restore legitimate PSN platinums

-- Games that had phantom platinums (from the audit):
-- DemoTester: Sekiro
-- Dex-Morgan: A Plague Tale: Requiem, Baldur's Gate 3, Dragon's Dogma: Dark Arisen, 
--             FINAL FANTASY VII REMAKE, God of War Ragnarök, Red Dead Redemption 2, 
--             Sekiro, Slender: The Arrival
-- ojjm11: Bugsnax, Dead Island 2, Donut County, Far Cry 5, Far Cry 6, HITMAN 3,
--         It Takes Two, Little Kitty Big City, Marvel's Spider-Man: Miles Morales, Road 96

UPDATE user_games ug
SET last_rarity_sync = NULL
FROM game_titles gt, platforms p
WHERE ug.game_title_id = gt.id
    AND ug.platform_id = p.id
    AND p.code IN ('PS3', 'PS4', 'PS5') -- Only PSN platforms
    AND gt.name IN (
        'Sekiro™: Shadows Die Twice',
        'A Plague Tale: Requiem',
        'Baldur''s Gate 3',
        'Dragon''s Dogma: Dark Arisen',
        'FINAL FANTASY VII REMAKE',
        'God of War Ragnarök',
        'Red Dead Redemption 2',
        'Slender: The Arrival',
        'Bugsnax',
        'Dead Island 2',
        'Donut County',
        'Far Cry® 5',
        'Far Cry® 6',
        'HITMAN 3',
        'It Takes Two',
        'Little Kitty, Big City',
        'Marvel''s Spider-Man: Miles Morales',
        'Road 96'
    )
    AND ug.has_platinum = true; -- Only reset games that actually have platinums

-- Show affected users and games
SELECT 
    p.username,
    gt.name as game_name,
    pl.code as platform,
    ug.last_rarity_sync
FROM user_games ug
JOIN profiles p ON ug.user_id = p.id
JOIN game_titles gt ON ug.game_title_id = gt.id
JOIN platforms pl ON ug.platform_id = pl.id
WHERE gt.name IN (
        'Sekiro™: Shadows Die Twice',
        'A Plague Tale: Requiem',
        'Baldur''s Gate 3',
        'Dragon''s Dogma: Dark Arisen',
        'FINAL FANTASY VII REMAKE',
        'God of War Ragnarök',
        'Red Dead Redemption 2',
        'Slender: The Arrival',
        'Bugsnax',
        'Dead Island 2',
        'Donut County',
        'Far Cry® 5',
        'Far Cry® 6',
        'HITMAN 3',
        'It Takes Two',
        'Little Kitty, Big City',
        'Marvel''s Spider-Man: Miles Morales',
        'Road 96'
    )
    AND pl.code IN ('PS3', 'PS4', 'PS5')
    AND ug.has_platinum = true
ORDER BY p.username, gt.name;
