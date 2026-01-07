-- Check if RESOGUN and Destiny exist in user_games for DaHead22
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
  AND gt.name IN ('RESOGUN™', 'Destiny')
ORDER BY gt.name;
