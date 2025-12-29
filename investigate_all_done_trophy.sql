-- Investigate why "All Done" is linked to "What Remains of Edith Finch"
-- This achievement doesn't belong to that game

-- Check the achievement details
SELECT 
    a.id,
    a.name,
    a.game_title_id,
    a.platform_achievement_id as psn_trophy_id,
    a.psn_trophy_type,
    a.is_platinum,
    gt.name as game_name
FROM achievements a
JOIN game_titles gt ON a.game_title_id = gt.id
WHERE a.id = 66303;

-- Check if there are OTHER games with "All Done" achievement
SELECT 
    a.id,
    a.name,
    a.psn_trophy_type,
    gt.name as game_name,
    a.platform_achievement_id
FROM achievements a
JOIN game_titles gt ON a.game_title_id = gt.id
WHERE a.name = 'All Done'
    AND a.platform = 'psn';

-- Check what the ACTUAL trophies are for "What Remains of Edith Finch"
SELECT 
    a.id,
    a.name,
    a.psn_trophy_type,
    a.is_platinum,
    a.platform_achievement_id
FROM achievements a
JOIN game_titles gt ON a.game_title_id = gt.id
WHERE gt.name = 'What Remains of Edith Finch'
ORDER BY a.psn_trophy_type, a.name;
