-- Check DanyGT37's game data
SELECT 
  COUNT(*) as total_games,
  SUM(earned_trophies) as total_trophies_earned,
  SUM(total_trophies) as total_trophies
FROM user_games
WHERE user_id = '68de8222-9da5-4362-ac9b-96b302a7d455';

-- Check platform breakdown
SELECT 
  pt.name as platform,
  COUNT(*) as game_count,
  SUM(ug.earned_trophies) as trophies_earned
FROM user_games ug
JOIN platforms pt ON pt.id = ug.platform_id
WHERE ug.user_id = '68de8222-9da5-4362-ac9b-96b302a7d455'
GROUP BY pt.name;
