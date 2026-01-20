-- Force the 7 games to be processed on next sync
-- Sets their last_rarity_sync to old date so sync thinks they need refreshing

UPDATE user_games 
SET last_rarity_sync = '2024-01-01 00:00:00+00'
WHERE user_id = (SELECT id FROM profiles WHERE psn_online_id = 'Dex-Morgan')
  AND game_title_id IN (
    SELECT id FROM game_titles 
    WHERE name IN (
      'A Plague Tale: Requiem',
      'Baldur''s Gate 3',
      'Destiny 2',
      'Red Dead Redemption 2',
      'Sekiro™: Shadows Die Twice',
      'Slender: The Arrival',
      'Stardew Valley'
    )
  )
RETURNING id, game_title_id, last_rarity_sync;
