-- Check RESOGUN, Destiny, and Ghost of Yōtei in user_games
SELECT 
  gt.name,
  ug.platform_id,
  ug.has_platinum,
  ug.platinum_trophies,
  ug.completion_percent,
  ug.earned_trophies,
  ug.total_trophies
FROM user_games ug
JOIN game_titles gt ON gt.id = ug.game_title_id
JOIN profiles p ON p.id = ug.user_id
WHERE p.psn_online_id = 'DaHead22'
  AND ug.platform_id = 1
  AND gt.name IN ('RESOGUN™', 'Destiny', 'Ghost of Yōtei');
