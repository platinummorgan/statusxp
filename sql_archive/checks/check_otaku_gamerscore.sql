-- Check Otaku's actual Xbox gamerscore from user_progress
SELECT 
  p.display_name,
  up.platform_id,
  CASE up.platform_id
    WHEN 10 THEN 'Xbox360'
    WHEN 11 THEN 'XboxOne'
    WHEN 12 THEN 'XboxSeriesX'
  END as platform_name,
  up.current_score as gamerscore,
  up.achievements_earned,
  up.total_achievements,
  up.completion_percent
FROM user_progress up
INNER JOIN profiles p ON p.id = up.user_id
WHERE p.display_name = 'Otaku'
  AND up.platform_id IN (10, 11, 12)
ORDER BY up.platform_id;

-- Check total gamerscore across all Xbox platforms
SELECT 
  p.display_name,
  SUM(up.current_score) as total_gamerscore,
  SUM(up.achievements_earned) as total_achievements,
  COUNT(DISTINCT up.platform_game_id) as total_games
FROM user_progress up
INNER JOIN profiles p ON p.id = up.user_id
WHERE p.display_name = 'Otaku'
  AND up.platform_id IN (10, 11, 12)
GROUP BY p.display_name;

-- Check what xbox_leaderboard_cache is showing
SELECT 
  display_name,
  gamerscore,
  achievement_count,
  total_games
FROM xbox_leaderboard_cache
WHERE display_name = 'Otaku';
