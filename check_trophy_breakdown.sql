-- Check trophy breakdown columns in user_games
SELECT 
    gt.name,
    ug.bronze_trophies,
    ug.silver_trophies,
    ug.gold_trophies,
    ug.platinum_trophies,
    ug.total_trophies,
    ug.earned_trophies
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
ORDER BY ug.updated_at DESC
LIMIT 10;
