-- Test the function output to see actual dates
SELECT 
  name,
  platforms[1]->>'code' as platform,
  last_played_at
FROM get_user_grouped_games((SELECT id FROM profiles LIMIT 1))
ORDER BY last_played_at DESC NULLS LAST
LIMIT 20;
