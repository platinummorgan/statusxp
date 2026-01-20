-- Diagnose DaHead22 Platinum Trophy Count Issue
-- Expected: 8 platinums, Showing: 6
-- User: djheygood (PSN: DaHead22)
-- User ID: 3c5206fb-6806-4f95-80d6-29ee7e974be9

-- Step 1: Verify user info
SELECT id as user_id, username, display_name, psn_online_id, xbox_gamertag
FROM profiles
WHERE id = '3c5206fb-6806-4f95-80d6-29ee7e974be9';

-- Step 2: Count all platinum achievements from user_achievements table
SELECT COUNT(*) as total_platinums
FROM user_achievements ua
INNER JOIN achievements a ON ua.achievement_id = a.id
WHERE ua.user_id = '3c5206fb-6806-4f95-80d6-29ee7e974be9'
  AND a.is_platinum = true;

-- Step 3: List all platinum achievements for DaHead22
SELECT 
    a.id as achievement_id,
    a.game_title_id,
    gt.name as game_title,
    a.name as achievement_name,
    a.platform,
    ua.earned_at,
    a.rarity_global,
    ua.statusxp_points
FROM user_achievements ua
INNER JOIN achievements a ON ua.achievement_id = a.id
LEFT JOIN game_titles gt ON a.game_title_id = gt.id
WHERE ua.user_id = '3c5206fb-6806-4f95-80d6-29ee7e974be9'
  AND a.is_platinum = true
ORDER BY ua.earned_at DESC;

-- Step 4: Check user_stats table for cached platinum_count
SELECT 
    total_games,
    completed_games,
    total_trophies,
    platinum_count,
    total_gamerscore,
    updated_at
FROM user_stats
WHERE user_id = '3c5206fb-6806-4f95-80d6-29ee7e974be9';

-- Step 5: Check for duplicate platinum achievements (same game)
SELECT 
    a.game_title_id,
    gt.name as game_title,
    COUNT(*) as platinum_count,
    ARRAY_AGG(a.id) as achievement_ids,
    ARRAY_AGG(a.platform) as platforms
FROM user_achievements ua
INNER JOIN achievements a ON ua.achievement_id = a.id
LEFT JOIN game_titles gt ON a.game_title_id = gt.id
WHERE ua.user_id = '3c5206fb-6806-4f95-80d6-29ee7e974be9'
  AND a.is_platinum = true
GROUP BY a.game_title_id, gt.name
HAVING COUNT(*) > 1;

-- Step 6: Check user_games table for platinum trophy counts
SELECT 
    ug.id,
    gt.name as game_title,
    ug.platform_id,
    p.name as platform_name,
    ug.platinum_trophies,
    ug.completion_percent,
    ug.has_platinum,
    ug.last_played_at
FROM user_games ug
INNER JOIN game_titles gt ON ug.game_title_id = gt.id
LEFT JOIN platforms p ON ug.platform_id = p.id
WHERE ug.user_id = '3c5206fb-6806-4f95-80d6-29ee7e974be9'
  AND ug.platinum_trophies > 0
ORDER BY ug.last_played_at DESC;

-- Step 7: Check psn_leaderboard_cache
SELECT 
    user_id,
    display_name,
    platinum_count,
    total_games,
    updated_at
FROM psn_leaderboard_cache
WHERE user_id = '3c5206fb-6806-4f95-80d6-29ee7e974be9';

-- Step 8: Check for NULL game_title_ids in achievements
SELECT COUNT(*) as platinums_with_null_game_id
FROM user_achievements ua
INNER JOIN achievements a ON ua.achievement_id = a.id
WHERE ua.user_id = '3c5206fb-6806-4f95-80d6-29ee7e974be9'
  AND a.is_platinum = true
  AND a.game_title_id IS NULL;
