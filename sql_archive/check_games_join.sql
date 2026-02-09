-- Check if games join is working for Steam
SELECT 
  ug.game_title,
  ug.platform_id,
  g.platform_game_id,
  g.name as games_table_name
FROM user_games ug
LEFT JOIN games g ON g.platform_id = ug.platform_id 
  AND g.name = ug.game_title
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND ug.platform_id = 4
LIMIT 5;
