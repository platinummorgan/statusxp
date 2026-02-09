-- Check if game_titles table exists
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name = 'game_titles';

-- Check columns in user_games view
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'user_games' 
ORDER BY ordinal_position;
