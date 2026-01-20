-- Find duplicate platinum trophies for Dex-Morgan
-- Shows games where you have multiple platinum entries

SELECT 
  g.name as game_name,
  g.id as game_title_id,
  g.metadata->>'psn_np_communication_id' as np_comm_id,
  COUNT(DISTINCT ua.id) as platinum_count,
  STRING_AGG(DISTINCT a.name, ' | ') as platinum_names
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id
JOIN game_titles g ON a.game_title_id = g.id
WHERE ua.user_id = (SELECT id FROM profiles WHERE psn_online_id = 'Dex-Morgan')
  AND a.is_platinum = true
GROUP BY g.name, g.id, g.metadata->>'psn_np_communication_id'
ORDER BY platinum_count DESC, g.name;

-- Show all RE4 variants now
SELECT 
  g.id,
  g.name,
  g.metadata->>'psn_np_communication_id' as np_comm_id,
  g.created_at,
  (SELECT COUNT(*) FROM achievements WHERE game_title_id = g.id) as total_achievements,
  (SELECT COUNT(*) FROM achievements WHERE game_title_id = g.id AND is_platinum = true) as platinums
FROM game_titles g
WHERE g.name ILIKE '%resident evil 4%'
ORDER BY g.created_at;
