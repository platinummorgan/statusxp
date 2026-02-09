-- Check if function exists
SELECT proname, prosrc 
FROM pg_proc 
WHERE proname = 'get_user_grouped_games';

-- Check user_games directly
SELECT 
  game_title,
  platform_id,
  last_played_at,
  user_id
FROM user_games
LIMIT 5;

-- Check if migration was applied
SELECT * FROM get_user_grouped_games('c5bc9aef-e158-4805-837e-e60e0f4df0eb')
LIMIT 5;
