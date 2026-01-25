-- Find what leaderboard views actually exist

-- 1. List all leaderboard-related views
SELECT table_name, table_type
FROM information_schema.tables
WHERE table_name LIKE '%leaderboard%'
  OR table_name LIKE '%rank%'
ORDER BY table_name;

-- 2. Check the actual column structure of leaderboard_cache
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'leaderboard_cache'
ORDER BY ordinal_position;

-- 3. Sample data from leaderboard_cache
SELECT *
FROM leaderboard_cache
LIMIT 5;

-- 4. Check user_progress hasn't been reverted
SELECT COUNT(*), SUM(current_score), AVG(current_score)
FROM user_progress
WHERE current_score > 0;
