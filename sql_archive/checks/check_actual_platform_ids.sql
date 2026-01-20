-- Check what platform_ids actually exist in games and user_progress
SELECT DISTINCT platform_id, COUNT(*) as count
FROM games
GROUP BY platform_id
ORDER BY platform_id;

SELECT DISTINCT platform_id, COUNT(*) as count  
FROM user_progress
GROUP BY platform_id
ORDER BY platform_id;
