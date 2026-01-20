-- Check RE4 situation for Dex-Morgan

-- Show all RE4 game_titles
SELECT 
  g.id,
  g.name,
  g.metadata->>'psn_np_communication_id' as np_comm_id,
  (SELECT COUNT(*) FROM achievements WHERE game_title_id = g.id) as total_achievements,
  (SELECT COUNT(*) FROM user_achievements ua 
   JOIN achievements a ON ua.achievement_id = a.id 
   WHERE a.game_title_id = g.id 
     AND ua.user_id = (SELECT id FROM profiles WHERE psn_online_id = 'Dex-Morgan')
  ) as user_achievements
FROM game_titles g
WHERE g.name ILIKE '%resident evil 4%'
ORDER BY g.created_at;

-- Show RE4 in user_games
SELECT 
  ug.id,
  g.id as game_title_id,
  g.name,
  g.metadata->>'psn_np_communication_id' as np_comm_id,
  ug.earned_trophies,
  ug.total_trophies,
  ug.has_platinum
FROM user_games ug
JOIN game_titles g ON ug.game_title_id = g.id
WHERE ug.user_id = (SELECT id FROM profiles WHERE psn_online_id = 'Dex-Morgan')
  AND g.name ILIKE '%resident evil 4%';

-- Force RE4 games to resync
UPDATE user_games 
SET last_rarity_sync = '2024-01-01 00:00:00+00'
WHERE user_id = (SELECT id FROM profiles WHERE psn_online_id = 'Dex-Morgan')
  AND game_title_id IN (
    SELECT id FROM game_titles WHERE name ILIKE '%resident evil 4%'
  )
RETURNING id, game_title_id, last_rarity_sync;
