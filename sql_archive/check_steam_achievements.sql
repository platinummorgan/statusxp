-- Check if Steam achievements were synced
SELECT 
  COUNT(DISTINCT platform_game_id) as steam_games_with_achievements,
  COUNT(*) as total_steam_achievements,
  jsonb_agg(DISTINCT platform_game_id ORDER BY platform_game_id) as steam_game_ids
FROM user_achievements
WHERE user_id = '35029ccf-0d16-4741-a2fe-1e5b9fee4e23'::uuid
  AND platform_id = 4;

-- Show sample Steam achievements
SELECT 
  ua.platform_game_id,
  g.name as game_name,
  COUNT(*) as achievements_earned
FROM user_achievements ua
LEFT JOIN games g ON g.platform_id = ua.platform_id AND g.platform_game_id = ua.platform_game_id
WHERE ua.user_id = '35029ccf-0d16-4741-a2fe-1e5b9fee4e23'::uuid
  AND ua.platform_id = 4
GROUP BY ua.platform_game_id, g.name
ORDER BY achievements_earned DESC
LIMIT 10;
