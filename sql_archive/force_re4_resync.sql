-- Force RE4 to be processed on next sync by making rarity appear stale

UPDATE user_games 
SET last_rarity_sync = '2024-01-01 00:00:00+00'  -- Set to old date to trigger rarity refresh
WHERE user_id = (SELECT id FROM profiles WHERE psn_online_id = 'Dex-Morgan')
  AND game_title_id = (SELECT id FROM game_titles WHERE name = 'Resident Evil 4')
RETURNING id, game_title_id, last_rarity_sync;
