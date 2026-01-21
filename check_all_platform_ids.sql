-- Check all platform IDs in database
SELECT DISTINCT platform_id, name
FROM games
WHERE platform_id IN (1, 2, 3, 4, 5, 9, 10, 11, 12)
ORDER BY platform_id
LIMIT 20;
