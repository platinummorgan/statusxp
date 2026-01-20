-- Check if achievements exist in achievements table for DanyGT37's games
SELECT 
  gt.name as game_name,
  COUNT(a.id) as achievements_in_db,
  ug.earned_trophies as should_have_earned
FROM user_games ug
INNER JOIN game_titles gt ON gt.id = ug.game_title_id
LEFT JOIN achievements a ON a.game_title_id = gt.id AND a.platform = 'steam'
WHERE ug.user_id = '68de8222-9da5-4362-ac9b-96b302a7d455'
  AND ug.platform_id = 4
  AND ug.earned_trophies > 0
GROUP BY gt.name, ug.earned_trophies
ORDER BY ug.earned_trophies DESC
LIMIT 10;

-- Check if maybe the upsert used wrong user_id or something
SELECT COUNT(*) as total_steam_user_achievements
FROM user_achievements ua
INNER JOIN achievements a ON a.id = ua.achievement_id
WHERE a.platform = 'steam';

-- Check if there are ANY user_achievements for DanyGT37 across all platforms
SELECT COUNT(*) as total_any_platform
FROM user_achievements
WHERE user_id = '68de8222-9da5-4362-ac9b-96b302a7d455';
