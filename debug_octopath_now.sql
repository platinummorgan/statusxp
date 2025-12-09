-- Check what values are in the database right now for Octopath
SELECT 
  gt.name,
  ug.earned_trophies,
  ug.total_trophies,
  ug.xbox_achievements_earned,
  ug.xbox_total_achievements,
  ug.completion_percent,
  -- Count what's actually in achievements table
  (SELECT COUNT(*) FROM achievements WHERE game_title_id = gt.id AND platform = 'xbox') as achievements_in_db
FROM user_games ug
JOIN game_titles gt ON gt.id = ug.game_title_id
JOIN platforms p ON p.id = ug.platform_id
WHERE gt.name ILIKE '%octopath%'
  AND p.code ILIKE '%xbox%';
