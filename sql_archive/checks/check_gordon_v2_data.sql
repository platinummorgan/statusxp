-- Check Gordon's Xbox stats in v2 schema
SELECT 
  p.display_name,
  p.xbox_gamertag,
  COUNT(DISTINCT up.platform_game_id) as total_games,
  SUM(up.current_score) as total_gamerscore,
  SUM(up.achievements_earned) as achievements_earned,
  SUM(up.total_achievements) as total_achievements,
  ROUND(AVG(up.completion_percentage), 2) as avg_completion
FROM profiles p
JOIN user_progress_v2 up ON up.user_id = p.id
JOIN platforms plat ON plat.id = up.platform_id
WHERE p.display_name = 'Gordon'
  AND plat.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')
GROUP BY p.display_name, p.xbox_gamertag;
