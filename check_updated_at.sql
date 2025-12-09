-- Check updated_at values for your games
SELECT 
  gt.name,
  p.code,
  ug.updated_at,
  ug.earned_trophies,
  ug.total_trophies
FROM user_games ug
JOIN game_titles gt ON gt.id = ug.game_title_id
JOIN platforms p ON p.id = ug.platform_id
ORDER BY ug.updated_at DESC NULLS LAST
LIMIT 20;
