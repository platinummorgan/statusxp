-- Check if any user_games have invalid game_title references
SELECT 
  COUNT(*) as total_user_games,
  COUNT(CASE WHEN gt.id IS NULL THEN 1 END) as missing_game_title,
  COUNT(CASE WHEN gt.id IS NOT NULL THEN 1 END) as valid_game_title
FROM user_games ug
LEFT JOIN game_titles gt ON ug.game_title_id = gt.id
WHERE ug.user_id = (SELECT id FROM profiles WHERE username = 'Dex-Morgan');
