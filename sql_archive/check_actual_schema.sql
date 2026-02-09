-- Check what games/user_progress tables actually exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND (table_name LIKE '%games%' OR table_name LIKE '%user_progress%')
ORDER BY table_name;

-- Check actual columns in games-related tables
SELECT table_name, column_name, data_type 
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name IN ('games', 'games_v2')
ORDER BY table_name, ordinal_position;

-- Check actual columns in user_progress-related tables
SELECT table_name, column_name, data_type 
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name IN ('user_progress', 'user_progress_v2')
ORDER BY table_name, ordinal_position;

-- Check actual columns in achievements-related tables
SELECT table_name, column_name, data_type 
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name IN ('achievements', 'achievements_v2')
ORDER BY table_name, ordinal_position;

-- Check actual columns in user_achievements-related tables
SELECT table_name, column_name, data_type 
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name IN ('user_achievements', 'user_achievements_v2')
ORDER BY table_name, ordinal_position;

-- Check if there are any views
SELECT table_name, view_definition
FROM information_schema.views
WHERE table_schema = 'public'
  AND (table_name LIKE '%games%' OR table_name LIKE '%user_progress%')
ORDER BY table_name;
