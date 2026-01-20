-- Find games with platinum trophy earned but has_platinum not set correctly
SELECT 
  gt.name,
  ug.platform_id,
  ug.platinum_trophies,
  ug.has_platinum,
  ug.completion_percent,
  ug.earned_trophies,
  ug.total_trophies,
  ug.updated_at
FROM user_games ug
JOIN game_titles gt ON gt.id = ug.game_title_id
JOIN profiles p ON p.id = ug.user_id
WHERE p.psn_online_id = 'DaHead22'
  AND ug.platform_id = 1
  AND ug.platinum_trophies > 0
  AND ug.has_platinum = false
ORDER BY ug.updated_at DESC;
