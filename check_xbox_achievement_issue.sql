-- Check Xbox achievement counts for Octopath Traveler and Ori
-- Issue: Showing 65/32 (203%) and 41/32 (128%) respectively

SELECT 
  gt.name AS game_name,
  p.code AS platform,
  ug.earned_trophies,
  ug.total_trophies,
  ug.xbox_achievements_earned,
  ug.xbox_total_achievements,
  gt.xbox_total_achievements AS game_title_total,
  CASE 
    WHEN ug.total_trophies > 0 THEN 
      ROUND((ug.earned_trophies::decimal / ug.total_trophies::decimal * 100), 1)
    ELSE 0
  END AS calculated_percent,
  -- Count actual achievements in achievements table
  (SELECT COUNT(*) 
   FROM achievements 
   WHERE game_title_id = gt.id 
   AND platform = 'xbox') AS achievements_table_total,
  -- Count earned achievements
  (SELECT COUNT(*) 
   FROM user_achievements ua
   JOIN achievements a ON a.id = ua.achievement_id
   WHERE a.game_title_id = gt.id 
   AND a.platform = 'xbox'
   AND ua.user_id = ug.user_id) AS achievements_table_earned
FROM user_games ug
JOIN game_titles gt ON gt.id = ug.game_title_id
JOIN platforms p ON p.id = ug.platform_id
WHERE gt.name ILIKE '%octopath%' 
   OR gt.name ILIKE '%ori%'
   AND p.code ILIKE '%xbox%'
ORDER BY gt.name;
