-- Check if Steam user_games have achievement data
SELECT 
  ug.id,
  gt.name,
  ug.earned_trophies,
  ug.total_trophies,
  ug.xbox_achievements_earned,
  ug.xbox_total_achievements
FROM user_games ug
JOIN game_titles gt ON gt.id = ug.game_title_id
WHERE gt.steam_app_id IS NOT NULL
LIMIT 5;
