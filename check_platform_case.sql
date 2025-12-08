-- Check what platform values actually exist in achievements table
SELECT DISTINCT platform, COUNT(*) as count
FROM achievements
WHERE game_title_id IN (327, 193, 108, 31)
GROUP BY platform
ORDER BY platform;

-- Check specific game 327
SELECT platform, COUNT(*) as count
FROM achievements
WHERE game_title_id = 327
GROUP BY platform;
