-- Check Xbox games in user_games table
SELECT 
  gt.name as game_name,
  ug.total_trophies,
  ug.earned_trophies,
  ug.xbox_total_achievements,
  ug.xbox_achievements_earned,
  ug.completion_percent,
  p.name as platform_name,
  p.code as platform_code
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
JOIN platforms p ON ug.platform_id = p.id
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND p.code LIKE '%Xbox%'
ORDER BY ug.updated_at DESC
LIMIT 10;
