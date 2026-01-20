-- Audit current database structure
-- Get exact column names and types for all tables

-- GAME_TITLES
SELECT 'game_titles' as table_name, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'game_titles'
ORDER BY ordinal_position;

-- USER_GAMES
SELECT 'user_games' as table_name, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'user_games'
ORDER BY ordinal_position;

-- ACHIEVEMENTS
SELECT 'achievements' as table_name, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'achievements'
ORDER BY ordinal_position;

-- USER_ACHIEVEMENTS
SELECT 'user_achievements' as table_name, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'user_achievements'
ORDER BY ordinal_position;

-- PROFILES
SELECT 'profiles' as table_name, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'profiles'
ORDER BY ordinal_position;

-- PLATFORMS
SELECT 'platforms' as table_name, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'platforms'
ORDER BY ordinal_position;
