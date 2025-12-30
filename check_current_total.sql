-- Check CURRENT total StatusXP (might have changed in last few minutes)
SELECT 
  SUM(statusxp_effective) as current_total_statusxp,
  COUNT(*) as total_games,
  COUNT(DISTINCT game_title_id) as unique_titles
FROM user_games 
WHERE user_id = (SELECT id FROM profiles WHERE username = 'Dex-Morgan');
