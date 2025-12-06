-- Check what user IDs exist and their game counts
SELECT 
  p.id as user_id,
  p.email,
  COUNT(DISTINCT ug.id) as game_count,
  COUNT(DISTINCT ut.id) as trophy_count
FROM profiles p
LEFT JOIN user_games ug ON ug.user_id = p.id
LEFT JOIN user_trophies ut ON ut.user_id = p.id
GROUP BY p.id, p.email
ORDER BY game_count DESC;

-- Check if demo-user-id has data
SELECT COUNT(*) as demo_games
FROM user_games
WHERE user_id = 'demo-user-id';

-- Check recent user activity
SELECT 
  user_id,
  COUNT(*) as games
FROM user_games
GROUP BY user_id;
