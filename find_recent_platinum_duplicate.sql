-- Find the duplicate platinum that appeared after database changes
-- Looking for the most recently added platinum that might be a duplicate

-- Check if any platinums were added/modified recently
SELECT 
    gt.name as game_name,
    a.name as achievement_name,
    ua.earned_at as earned_date,
    ua.created_at as added_to_db,
    a.id as achievement_id,
    gt.id as game_title_id
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id
JOIN game_titles gt ON a.game_title_id = gt.id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
    AND a.is_platinum = true
ORDER BY ua.created_at DESC
LIMIT 20;

-- Check for games with very similar names that might be duplicates
SELECT 
    LOWER(REPLACE(REPLACE(gt.name, '™', ''), '®', '')) as normalized_name,
    COUNT(*) as plat_count,
    STRING_AGG(gt.name, ' | ') as game_names,
    STRING_AGG(gt.id::text, ', ') as game_ids
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id
JOIN game_titles gt ON a.game_title_id = gt.id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
    AND a.is_platinum = true
GROUP BY LOWER(REPLACE(REPLACE(gt.name, '™', ''), '®', ''))
HAVING COUNT(*) > 1;
