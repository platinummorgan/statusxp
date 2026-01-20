-- Compare the two Assassin's Creed Mirage game_title entries to see what's different

-- Compare game_titles metadata
SELECT 
    gt.id as game_title_id,
    gt.name,
    gt.cover_url,
    gt.created_at,
    gt.updated_at
FROM game_titles gt
WHERE gt.id IN (204, 2488)
ORDER BY gt.id;

-- Compare Xbox achievements between the two entries
-- Check if they have the same achievement names (to see if they're truly the same game)
SELECT 
    a.game_title_id,
    a.name as achievement_name,
    a.description,
    a.id as achievement_id
FROM achievements a
WHERE a.game_title_id IN (204, 2488)
  AND a.platform = 'xbox'
ORDER BY a.game_title_id, a.name
LIMIT 50;

-- Check for duplicate achievement names across both entries
SELECT 
    a.name as achievement_name,
    COUNT(*) as occurrence_count,
    ARRAY_AGG(DISTINCT a.game_title_id) as game_title_ids,
    ARRAY_AGG(DISTINCT a.id) as achievement_ids
FROM achievements a
WHERE a.game_title_id IN (204, 2488)
  AND a.platform = 'xbox'
GROUP BY a.name
HAVING COUNT(*) > 1
ORDER BY occurrence_count DESC;
