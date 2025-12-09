-- Fix Octopath and Ori by counting actual achievements in database
-- The correct total should be 88 for Octopath based on your screenshot

-- First check what we have in achievements table
SELECT 
  gt.name,
  COUNT(*) as actual_achievement_count
FROM achievements a
JOIN game_titles gt ON gt.id = a.game_title_id
WHERE a.platform = 'xbox'
  AND (gt.name ILIKE '%octopath%' OR gt.name ILIKE '%ori%blind%')
GROUP BY gt.name;

-- If the count matches what Xbox shows (88), apply this fix:
-- UPDATE user_games ug
-- SET 
--   total_trophies = (SELECT COUNT(*) FROM achievements WHERE game_title_id = ug.game_title_id AND platform = 'xbox'),
--   xbox_total_achievements = (SELECT COUNT(*) FROM achievements WHERE game_title_id = ug.game_title_id AND platform = 'xbox')
-- FROM game_titles gt, platforms p
-- WHERE ug.game_title_id = gt.id
--   AND ug.platform_id = p.id
--   AND p.code ILIKE '%xbox%'
--   AND (gt.name ILIKE '%octopath%' OR gt.name ILIKE '%ori%blind%');
