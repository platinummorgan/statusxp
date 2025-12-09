-- Check current Xbox data for your account
SELECT 
  gt.name,
  p.code,
  ug.earned_trophies,
  ug.total_trophies,
  ug.xbox_achievements_earned,
  ug.xbox_total_achievements,
  ug.xbox_current_gamerscore,
  ug.xbox_max_gamerscore
FROM user_games ug
JOIN game_titles gt ON gt.id = ug.game_title_id
JOIN platforms p ON p.id = ug.platform_id
WHERE p.code ILIKE '%xbox%'
ORDER BY gt.name
LIMIT 20;
