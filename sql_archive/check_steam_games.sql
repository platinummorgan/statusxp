-- Check if Steam games exist for your user
SELECT 
  'Your Steam Games' as check_name,
  COUNT(*) as count
FROM games
WHERE platform_id = 4;

SELECT 
  'Your Steam user_progress' as check_name,
  COUNT(*) as count
FROM user_progress
WHERE platform_id = 4
  AND user_id = (SELECT id FROM auth.users WHERE email = 'mdorminey79@gmail.com');

-- Check steam_leaderboard_cache view definition
SELECT pg_get_viewdef('steam_leaderboard_cache', true);
