-- Find games where bronze trophy counts don't match between user_games and actual earned trophies
SELECT 
    gt.name AS game_name,
    ug.bronze_trophies AS expected_bronze,
    COUNT(CASE WHEN t.tier = 'bronze' AND ut.earned_at IS NOT NULL THEN 1 END) AS actual_bronze,
    ug.bronze_trophies - COUNT(CASE WHEN t.tier = 'bronze' AND ut.earned_at IS NOT NULL THEN 1 END) AS missing_bronze
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
JOIN trophies t ON t.game_title_id = gt.id
LEFT JOIN user_trophies ut ON ut.trophy_id = t.id 
    AND ut.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
GROUP BY gt.name, ug.bronze_trophies, gt.id
HAVING ug.bronze_trophies != COUNT(CASE WHEN t.tier = 'bronze' AND ut.earned_at IS NOT NULL THEN 1 END)
ORDER BY missing_bronze DESC;
