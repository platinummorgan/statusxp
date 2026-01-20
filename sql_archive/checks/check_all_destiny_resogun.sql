-- Check ALL entries for RESOGUN and Destiny (both PSN and Xbox)
SELECT 
  gt.name,
  ug.platform_id,
  CASE 
    WHEN ug.platform_id = 1 THEN 'PSN'
    WHEN ug.platform_id = 2 THEN 'Xbox'
    WHEN ug.platform_id = 3 THEN 'Steam'
  END as platform_name,
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
ORDER BY gt.name, ug.platform_id;
