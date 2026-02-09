-- DIAGNOSTIC: Check actual database state for user 84b60ad6-cb2c-484f-8953-bf814551fd7a

-- 1. What tables actually exist?
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name LIKE '%user_progress%'
ORDER BY table_name;

-- 2. What columns does user_progress actually have?
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'user_progress'
ORDER BY ordinal_position;

-- 3. What columns does user_progress_v2 have (if it exists)?
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'user_progress_v2'
ORDER BY ordinal_position;

-- 4. How many rows exist in each table for this user?
SELECT 'user_progress' as table_name, COUNT(*) as row_count
FROM user_progress
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
UNION ALL
SELECT 'user_progress_v2', COUNT(*)
FROM user_progress_v2
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- 5. Does user_achievements have data from the first sync?
SELECT COUNT(*) as total_achievements,
       COUNT(DISTINCT platform_game_id) as unique_games,
       COUNT(*) FILTER (WHERE unlocked_at IS NOT NULL) as earned_achievements
FROM user_achievements
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';
