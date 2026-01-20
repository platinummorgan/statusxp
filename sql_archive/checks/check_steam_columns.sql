-- Check actual column names in user_games
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'user_games' 
  AND column_name LIKE '%steam%'
ORDER BY column_name;

-- Check their actual progress without filtering
SELECT 
  gt.name,
  ug.*
FROM user_games ug
INNER JOIN game_titles gt ON gt.id = ug.game_title_id
WHERE ug.user_id = '68de8222-9da5-4362-ac9b-96b302a7d455'
  AND ug.platform_id = 4
ORDER BY gt.name
LIMIT 5;
