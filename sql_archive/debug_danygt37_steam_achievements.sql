-- Deep dive into DanyGT37's Steam data

-- Check user_games for Steam
SELECT COUNT(*) as steam_games_in_user_games
FROM user_games
WHERE user_id = '68de8222-9da5-4362-ac9b-96b302a7d455'
  AND platform_id = 4;

-- Check if achievements exist in achievements table for any of their games
SELECT 
  gt.name as game_name,
  COUNT(a.id) as total_achievements_available
FROM user_games ug
INNER JOIN game_titles gt ON gt.id = ug.game_title_id
LEFT JOIN achievements a ON a.game_title_id = gt.id AND a.platform = 'steam'
WHERE ug.user_id = '68de8222-9da5-4362-ac9b-96b302a7d455'
  AND ug.platform_id = 4
GROUP BY gt.name
ORDER BY total_achievements_available DESC
LIMIT 10;

-- Check if any Steam achievements were earned
SELECT 
  gt.name as game_name,
  a.name as achievement_name,
  ua.earned_at
FROM user_achievements ua
INNER JOIN achievements a ON a.id = ua.achievement_id
INNER JOIN game_titles gt ON gt.id = a.game_title_id
WHERE ua.user_id = '68de8222-9da5-4362-ac9b-96b302a7d455'
  AND a.platform = 'steam'
LIMIT 5;

-- Check their progress data
SELECT 
  gt.name,
  ug.steam_current_achievements,
  ug.steam_total_achievements
FROM user_games ug
INNER JOIN game_titles gt ON gt.id = ug.game_title_id
WHERE ug.user_id = '68de8222-9da5-4362-ac9b-96b302a7d455'
  AND ug.platform_id = 4
  AND ug.steam_current_achievements > 0
ORDER BY ug.steam_current_achievements DESC
LIMIT 10;
