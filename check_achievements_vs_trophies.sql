-- Check if there's an achievements table with platform column
SELECT 
  COUNT(*) as total_achievements,
  platform,
  game_title_id
FROM achievements
WHERE game_title_id = 327
GROUP BY platform, game_title_id

UNION ALL

SELECT 
  COUNT(*) as total_trophies,
  'PSN' as platform,
  game_title_id
FROM trophies
WHERE game_title_id = 327
GROUP BY game_title_id;
