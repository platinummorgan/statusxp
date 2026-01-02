-- Investigate platform display issues in Game Browser
-- User reports Steam games showing as PSN, and some games having no platform

-- 1. Check Deathloop specifically - what platforms does it have?
SELECT 
    gt.id as game_id,
    gt.name as game_name,
    a.platform,
    COUNT(*) as achievement_count
FROM game_titles gt
LEFT JOIN achievements a ON a.game_title_id = gt.id
WHERE gt.name ILIKE '%deathloop%'
GROUP BY gt.id, gt.name, a.platform
ORDER BY gt.name, a.platform;

-- 2. Find games that have achievements on MULTIPLE platforms (cross-platform games)
SELECT 
    gt.id as game_id,
    gt.name as game_name,
    STRING_AGG(DISTINCT a.platform, ', ' ORDER BY a.platform) as platforms,
    COUNT(DISTINCT a.platform) as platform_count
FROM game_titles gt
INNER JOIN achievements a ON a.game_title_id = gt.id
GROUP BY gt.id, gt.name
HAVING COUNT(DISTINCT a.platform) > 1
ORDER BY platform_count DESC, gt.name
LIMIT 20;

-- 3. Find games that have NO achievements at all
SELECT 
    gt.id as game_id,
    gt.name as game_name,
    gt.cover_url
FROM game_titles gt
LEFT JOIN achievements a ON a.game_title_id = gt.id
WHERE a.id IS NULL
ORDER BY gt.name
LIMIT 20;

-- 4. Check platform distribution across all games
SELECT 
    a.platform,
    COUNT(DISTINCT a.game_title_id) as game_count,
    COUNT(*) as achievement_count
FROM achievements a
GROUP BY a.platform
ORDER BY game_count DESC;

-- 5. Sample of games per platform to verify the data
-- PSN games
SELECT gt.name, 'psn' as platform
FROM game_titles gt
INNER JOIN achievements a ON a.game_title_id = gt.id
WHERE a.platform = 'psn'
GROUP BY gt.id, gt.name
ORDER BY gt.name
LIMIT 10;

-- Steam games
SELECT gt.name, 'steam' as platform
FROM game_titles gt
INNER JOIN achievements a ON a.game_title_id = gt.id
WHERE a.platform = 'steam'
GROUP BY gt.id, gt.name
ORDER BY gt.name
LIMIT 10;

-- Xbox games
SELECT gt.name, 'xbox' as platform
FROM game_titles gt
INNER JOIN achievements a ON a.game_title_id = gt.id
WHERE a.platform = 'xbox'
GROUP BY gt.id, gt.name
ORDER BY gt.name
LIMIT 10;
