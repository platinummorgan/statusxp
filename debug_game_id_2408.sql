-- Check the relationship between user_games and game_titles
SELECT 
  ug.id as user_game_id,
  ug.game_title_id,
  gt.id as game_title_actual_id,
  gt.name,
  (SELECT COUNT(*) FROM trophies t WHERE t.game_title_id = ug.game_title_id) as trophy_count
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
WHERE ug.id = 2408
  OR ug.game_title_id = 2408
LIMIT 5;
