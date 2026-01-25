-- Check profiles table columns
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'profiles' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check leaderboard_cache columns
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'leaderboard_cache' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check user_progress columns  
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'user_progress' 
  AND table_schema = 'public'
ORDER BY ordinal_position;
