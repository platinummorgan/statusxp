-- Audit all entries of Assassin's Creed Unity across all platforms

-- Get game titles matching Assassin's Creed Unity
SELECT 
    gt.id as game_title_id,
    gt.name,
    gt.cover_url,
    ARRAY_AGG(DISTINCT a.platform) as platforms,
    COUNT(DISTINCT a.id) as total_achievements
FROM game_titles gt
LEFT JOIN achievements a ON a.game_title_id = gt.id
WHERE gt.name ILIKE '%Assassin%Creed%Unity%'
GROUP BY gt.id, gt.name, gt.cover_url
ORDER BY gt.name;

-- Get detailed breakdown by platform
SELECT 
    gt.id as game_title_id,
    gt.name as game_name,
    a.platform,
    a.platform_game_id,
    COUNT(a.id) as achievement_count,
    MIN(a.created_at) as first_sync,
    MAX(a.updated_at) as last_updated
FROM game_titles gt
JOIN achievements a ON a.game_title_id = gt.id
WHERE gt.name ILIKE '%Assassin%Creed%Unity%'
GROUP BY gt.id, gt.name, a.platform, a.platform_game_id
ORDER BY gt.name, a.platform;

-- Get all achievement details for Assassin's Creed Unity
SELECT 
    gt.id as game_title_id,
    gt.name as game_name,
    a.platform,
    a.platform_game_id,
    a.id as achievement_id,
    a.name as achievement_name,
    a.description,
    a.rarity_percentage,
    a.icon_url
FROM game_titles gt
JOIN achievements a ON a.game_title_id = gt.id
WHERE gt.name ILIKE '%Assassin%Creed%Unity%'
ORDER BY gt.name, a.platform, a.rarity_percentage DESC NULLS LAST
LIMIT 100;
