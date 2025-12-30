-- Find which user has 1184 games
SELECT 
  id,
  username,
  psn_online_id,
  xbox_gamertag,
  (SELECT COUNT(*) FROM user_games WHERE user_id = p.id) as game_count,
  (SELECT COUNT(*) FROM user_trophies WHERE user_id = p.id) as trophy_count
FROM profiles p
WHERE id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d';
