-- Check if Ghost of Yotei and Destiny 2 exist for DaHead22 (djheygood)
-- User ID: 3c5206fb-6806-4f95-80d6-29ee7e974be9

-- Query 1: Check if these games exist in user_games table
SELECT 
    ug.id, 
    gt.name, 
    ug.platform_id, 
    p.name as platform_name,
    ug.platinum_trophies, 
    ug.completion_percent, 
    ug.has_platinum, 
    ug.last_played_at,
    ug.created_at
FROM user_games ug
INNER JOIN game_titles gt ON ug.game_title_id = gt.id
LEFT JOIN platforms p ON ug.platform_id = p.id
WHERE ug.user_id = '3c5206fb-6806-4f95-80d6-29ee7e974be9'
  AND (gt.name LIKE '%Ghost of Yotei%' OR gt.name LIKE '%Destiny 2%')
ORDER BY ug.last_played_at DESC;

-- Query 2: Check if platinum achievements exist for these games
SELECT 
    ua.id,
    gt.name as game_title,
    a.name as achievement_name,
    a.is_platinum,
    ua.earned_at,
    a.rarity_global,
    a.statusxp_points
FROM user_achievements ua
INNER JOIN achievements a ON ua.achievement_id = a.id
INNER JOIN game_titles gt ON a.game_title_id = gt.id
WHERE ua.user_id = '3c5206fb-6806-4f95-80d6-29ee7e974be9'
  AND (gt.name LIKE '%Ghost of Yotei%' OR gt.name LIKE '%Destiny 2%')
  AND a.is_platinum = true;

-- Query 3: Check if these games exist in game_titles at all
SELECT 
    id, 
    name, 
    platform_id, 
    created_at
FROM game_titles
WHERE name LIKE '%Ghost of Yotei%' 
   OR name LIKE '%Destiny 2%'
ORDER BY name;

-- Query 4: Check all games for this user to see what we have
SELECT 
    gt.name,
    ug.platinum_trophies,
    ug.has_platinum,
    ug.completion_percent,
    ug.last_played_at
FROM user_games ug
INNER JOIN game_titles gt ON ug.game_title_id = gt.id
WHERE ug.user_id = '3c5206fb-6806-4f95-80d6-29ee7e974be9'
ORDER BY ug.last_played_at DESC NULLS LAST;
