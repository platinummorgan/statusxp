-- Check if user_games has data
SELECT COUNT(*) as total_games, user_id
FROM user_games
GROUP BY user_id
LIMIT 5;

-- Check profiles
SELECT id FROM profiles LIMIT 1;

-- Try calling function with actual user_id
SELECT 
  name,
  last_played_at
FROM get_user_grouped_games('c5bc9aef-e158-4805-837e-e60e0f4df0eb')
LIMIT 10;
