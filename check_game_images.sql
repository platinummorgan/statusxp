-- Check if we have game cover URLs
SELECT 
    gt.name,
    gt.cover_url,
    LENGTH(gt.cover_url) as url_length,
    CASE 
        WHEN gt.cover_url IS NULL THEN 'NULL'
        WHEN gt.cover_url = '' THEN 'EMPTY'
        WHEN gt.cover_url LIKE 'http%' THEN 'HAS URL'
        ELSE 'OTHER'
    END as url_status
FROM game_titles gt
JOIN user_games ug ON ug.game_title_id = gt.id
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
ORDER BY ug.updated_at DESC
LIMIT 10;
