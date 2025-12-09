-- Check if last_played_at has useful data
SELECT 
  gt.name,
  ug.last_played_at,
  ug.earned_trophies
FROM user_games ug
JOIN game_titles gt ON gt.id = ug.game_title_id
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND ug.last_played_at IS NOT NULL
ORDER BY ug.last_played_at DESC
LIMIT 10;
