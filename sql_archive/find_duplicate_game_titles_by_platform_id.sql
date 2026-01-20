-- Find duplicate game_title entries by platform ID
-- Run this AFTER migrating IDs from metadata to columns

-- PSN duplicates (same NPWR ID in multiple game_title rows)
SELECT 
    psn_npwr_id,
    COUNT(*) as duplicate_count,
    ARRAY_AGG(id ORDER BY created_at) as game_title_ids,
    ARRAY_AGG(name ORDER BY created_at) as names
FROM game_titles
WHERE psn_npwr_id IS NOT NULL
GROUP BY psn_npwr_id
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- Xbox duplicates (same Title ID in multiple game_title rows)
SELECT 
    xbox_title_id,
    COUNT(*) as duplicate_count,
    ARRAY_AGG(id ORDER BY created_at) as game_title_ids,
    ARRAY_AGG(name ORDER BY created_at) as names
FROM game_titles
WHERE xbox_title_id IS NOT NULL
GROUP BY xbox_title_id
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- Steam duplicates (same App ID in multiple game_title rows)
SELECT 
    steam_app_id,
    COUNT(*) as duplicate_count,
    ARRAY_AGG(id ORDER BY created_at) as game_title_ids,
    ARRAY_AGG(name ORDER BY created_at) as names
FROM game_titles
WHERE steam_app_id IS NOT NULL
GROUP BY steam_app_id
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- Summary
SELECT 
    'PSN' as platform,
    COUNT(DISTINCT psn_npwr_id) as duplicate_games
FROM game_titles
WHERE psn_npwr_id IS NOT NULL
GROUP BY psn_npwr_id
HAVING COUNT(*) > 1

UNION ALL

SELECT 
    'Xbox' as platform,
    COUNT(DISTINCT xbox_title_id) as duplicate_games
FROM game_titles
WHERE xbox_title_id IS NOT NULL
GROUP BY xbox_title_id
HAVING COUNT(*) > 1

UNION ALL

SELECT 
    'Steam' as platform,
    COUNT(DISTINCT steam_app_id) as duplicate_games
FROM game_titles
WHERE steam_app_id IS NOT NULL
GROUP BY steam_app_id
HAVING COUNT(*) > 1;
