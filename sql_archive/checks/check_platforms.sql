-- Check what platforms exist and their game counts
SELECT 
  pl.code,
  pl.name,
  COUNT(DISTINCT ug.game_title_id) as games_count,
  COUNT(DISTINCT ug.user_id) as users_count
FROM platforms pl
LEFT JOIN user_games ug ON pl.id = ug.platform_id
GROUP BY pl.code, pl.name
ORDER BY games_count DESC;
