-- Check user_games view structure
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'user_games' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- Also check if there's a platform_game_id column
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'user_games' 
  AND column_name LIKE '%platform%'
  AND table_schema = 'public';
