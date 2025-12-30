-- Check if X_imThumper_X exists and has data
SELECT 
  p.username,
  p.psn_online_id,
  p.last_psn_sync_at,
  (SELECT COUNT(*) FROM user_trophies WHERE user_id = p.id) as trophy_count,
  (SELECT COUNT(*) FROM user_games WHERE user_id = p.id) as game_count
FROM profiles p
WHERE LOWER(username) LIKE '%thumper%';
