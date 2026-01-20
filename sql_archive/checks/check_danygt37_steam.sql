-- Check DanyGT37's Steam data
SELECT 
  p.id,
  p.display_name,
  p.steam_id,
  p.show_on_leaderboard
FROM profiles p
WHERE p.id = '68de8222-9da5-4362-ac9b-96b302a7d455';

-- Check Steam games
SELECT COUNT(*) as steam_games
FROM user_games
WHERE user_id = '68de8222-9da5-4362-ac9b-96b302a7d455'
  AND game_title_id IN (SELECT id FROM game_titles WHERE platform = 'steam');

-- Check Steam achievements
SELECT COUNT(*) as steam_achievements
FROM user_achievements ua
INNER JOIN achievements a ON a.id = ua.achievement_id
WHERE ua.user_id = '68de8222-9da5-4362-ac9b-96b302a7d455'
  AND a.platform = 'steam';

-- Check current cache
SELECT * FROM steam_leaderboard_cache
WHERE user_id = '68de8222-9da5-4362-ac9b-96b302a7d455';
