-- List all platinum games for DaHead22
SELECT 
  gt.name,
  ug.platform_id,
  ug.has_platinum,
  ug.platinum_trophies,
  ug.completion_percent,
  ug.earned_trophies,
  ug.total_trophies,
  ug.updated_at
FROM user_games ug
JOIN game_titles gt ON gt.id = ug.game_title_id
JOIN profiles p ON p.id = ug.user_id
WHERE p.psn_online_id = 'DaHead22'
  AND ug.platform_id = 1
  AND ug.has_platinum = true
ORDER BY ug.updated_at DESC;
