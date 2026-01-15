-- Check last_trophy_earned_at and last_played_at for games
SELECT 
  gt.name as game_name,
  p.code as platform,
  ug.last_trophy_earned_at,
  ug.last_played_at,
  ug.earned_trophies,
  ug.total_trophies,
  ug.updated_at
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
JOIN platforms p ON ug.platform_id = p.id
JOIN profiles pr ON ug.user_id = pr.id
WHERE pr.username = 'Dex-Morgan'
ORDER BY ug.last_trophy_earned_at DESC NULLS LAST
LIMIT 20;
