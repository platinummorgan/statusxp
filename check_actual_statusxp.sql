-- Get Dex-Morgan's actual total StatusXP from all user_games
SELECT 
  SUM(statusxp_effective) as total_statusxp,
  COUNT(*) as total_games
FROM user_games 
WHERE user_id = (SELECT id FROM profiles WHERE username = 'Dex-Morgan');
