-- Identify Xbox achievements that need rarity data
-- These have NULL rarity_global and need to be re-synced

SELECT 
  COUNT(*) as total_xbox_achievements_needing_rarity,
  COUNT(DISTINCT game_title_id) as affected_games,
  'Run Xbox rarity sync to populate rarity_global' as action_needed
FROM achievements
WHERE platform = 'xbox'
AND rarity_global IS NULL
AND include_in_score = true;

-- Show which Xbox games need rarity sync
SELECT DISTINCT
  gt.id as game_title_id,
  gt.title as game_title,
  COUNT(*) as achievements_without_rarity
FROM achievements a
JOIN game_titles gt ON gt.id = a.game_title_id
WHERE a.platform = 'xbox'
AND a.rarity_global IS NULL
AND a.include_in_score = true
GROUP BY gt.id, gt.title
ORDER BY achievements_without_rarity DESC
LIMIT 20;
