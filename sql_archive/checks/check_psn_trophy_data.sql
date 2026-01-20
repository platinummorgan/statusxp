-- Check if PSN user_games have trophy data
SELECT 
  ug.id,
  gt.name,
  p.code as platform,
  ug.earned_trophies,
  ug.total_trophies,
  ug.bronze_trophies,
  ug.silver_trophies,
  ug.gold_trophies,
  ug.platinum_trophies,
  ug.xbox_achievements_earned,
  ug.xbox_total_achievements,
  ug.completion_percent
FROM user_games ug
JOIN game_titles gt ON gt.id = ug.game_title_id
JOIN platforms p ON p.id = ug.platform_id
WHERE p.code = 'psn'
  AND gt.name ILIKE '%Disney Dreamlight Valley%'
LIMIT 5;
