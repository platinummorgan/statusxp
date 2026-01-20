-- Find users with games but no achievements (affected by broken RLS)
SELECT 
  p.display_name,
  p.id,
  COUNT(DISTINCT ug.game_title_id) as total_games,
  SUM(ug.earned_trophies) as earned_achievements_claimed,
  COUNT(ua.id) as actual_achievements_in_db,
  p.created_at as user_created
FROM profiles p
INNER JOIN user_games ug ON ug.user_id = p.id
LEFT JOIN user_achievements ua ON ua.user_id = p.id
WHERE ug.earned_trophies > 0
GROUP BY p.id, p.display_name, p.created_at
HAVING COUNT(ua.id) = 0
ORDER BY p.created_at DESC;
