-- Find all games with duplicate achievements across different game_title entries

-- Find duplicate achievements (same name + platform across different game_title_ids)
SELECT 
    a.name as achievement_name,
    a.platform,
    COUNT(DISTINCT a.game_title_id) as game_title_count,
    COUNT(*) as total_duplicates,
    ARRAY_AGG(DISTINCT a.game_title_id ORDER BY a.game_title_id) as affected_game_title_ids,
    ARRAY_AGG(DISTINCT gt.name) as game_names
FROM achievements a
JOIN game_titles gt ON gt.id = a.game_title_id
GROUP BY a.name, a.platform
HAVING COUNT(DISTINCT a.game_title_id) > 1
ORDER BY total_duplicates DESC, game_title_count DESC
LIMIT 100;

-- Summary: How many games are affected by this issue
SELECT 
    COUNT(DISTINCT game_title_pair) as affected_game_pairs,
    COUNT(*) as total_duplicate_achievements,
    SUM(CASE WHEN platform = 'xbox' THEN 1 ELSE 0 END) as xbox_duplicates,
    SUM(CASE WHEN platform = 'psn' THEN 1 ELSE 0 END) as psn_duplicates,
    SUM(CASE WHEN platform = 'steam' THEN 1 ELSE 0 END) as steam_duplicates
FROM (
    SELECT 
        a.name,
        a.platform,
        ARRAY_AGG(DISTINCT a.game_title_id ORDER BY a.game_title_id) as game_title_pair
    FROM achievements a
    GROUP BY a.name, a.platform
    HAVING COUNT(DISTINCT a.game_title_id) > 1
) as duplicates;

-- Find game titles with the most duplicate achievements
SELECT 
    gt.name as game_name,
    COUNT(DISTINCT a.name) as duplicate_achievement_count,
    ARRAY_AGG(DISTINCT a.platform) as platforms_affected,
    ARRAY_AGG(DISTINCT gt.id) as game_title_ids
FROM achievements a
JOIN game_titles gt ON gt.id = a.game_title_id
WHERE EXISTS (
    SELECT 1 
    FROM achievements a2 
    WHERE a2.name = a.name 
      AND a2.platform = a.platform 
      AND a2.game_title_id != a.game_title_id
)
GROUP BY gt.name
ORDER BY duplicate_achievement_count DESC
LIMIT 50;
