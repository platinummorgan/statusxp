-- Find and fix data inconsistencies where user_games.has_platinum=true
-- but no corresponding platinum achievement exists in user_achievements

-- Step 1: Find all inconsistencies
SELECT 
    ug.user_id,
    ug.game_title_id,
    ug.platform_id,
    gt.name as game_name,
    p.name as platform_name,
    ug.platinum_trophies,
    ug.has_platinum,
    COUNT(ua.id) as actual_platinums_in_db
FROM user_games ug
INNER JOIN game_titles gt ON ug.game_title_id = gt.id
LEFT JOIN platforms p ON ug.platform_id = p.id
LEFT JOIN achievements a ON a.game_title_id = ug.game_title_id 
    AND a.platform = CASE 
        WHEN p.code = 'PS5' THEN 'psn'
        WHEN p.code = 'PS4' THEN 'psn'
        WHEN p.code = 'PS3' THEN 'psn'
        WHEN p.code = 'PSVITA' THEN 'psn'
        WHEN p.code LIKE 'XBOX%' THEN 'xbox'
        WHEN p.code = 'STEAM' THEN 'steam'
        ELSE 'unknown'
    END
    AND a.is_platinum = true
LEFT JOIN user_achievements ua ON ua.achievement_id = a.id 
    AND ua.user_id = ug.user_id
WHERE ug.has_platinum = true
GROUP BY ug.user_id, ug.game_title_id, ug.platform_id, gt.name, p.name, ug.platinum_trophies, ug.has_platinum
HAVING COUNT(ua.id) = 0
ORDER BY gt.name;

-- Step 2: Fix inconsistencies by setting has_platinum back to false
-- This will force the next sync to re-fetch trophy data correctly
UPDATE user_games ug
SET 
    has_platinum = false,
    platinum_trophies = 0,
    sync_failed = true,
    sync_error = 'Data inconsistency detected: has_platinum was true but no achievements in DB',
    last_sync_attempt = NOW()
WHERE ug.has_platinum = true
AND NOT EXISTS (
    SELECT 1 
    FROM achievements a
    INNER JOIN user_achievements ua ON ua.achievement_id = a.id
    WHERE a.game_title_id = ug.game_title_id
        AND a.is_platinum = true
        AND ua.user_id = ug.user_id
);

-- Step 3: Verify the fix worked
SELECT 
    'After cleanup' as status,
    COUNT(*) as inconsistent_records
FROM user_games ug
WHERE ug.has_platinum = true
AND NOT EXISTS (
    SELECT 1 
    FROM achievements a
    INNER JOIN user_achievements ua ON ua.achievement_id = a.id
    WHERE a.game_title_id = ug.game_title_id
        AND a.is_platinum = true
        AND ua.user_id = ug.user_id
);
