-- Identify Xbox achievements that need rarity data
-- These have NULL rarity_global and need to be re-synced

WITH xbox_platforms AS (
  SELECT id
  FROM platforms
  WHERE code ILIKE 'xbox%'
     OR name ILIKE 'xbox%'
)
SELECT 
  COUNT(*) as total_xbox_achievements_needing_rarity,
  COUNT(DISTINCT a.platform_game_id) as affected_games,
  'Run Xbox rarity sync to populate rarity_global' as action_needed
FROM achievements a
WHERE a.platform_id IN (SELECT id FROM xbox_platforms)
  AND a.rarity_global IS NULL
  AND a.include_in_score = true;

-- Show which Xbox games need rarity sync
WITH xbox_platforms AS (
  SELECT id
  FROM platforms
  WHERE code ILIKE 'xbox%'
     OR name ILIKE 'xbox%'
)
SELECT
  g.platform_game_id as game_title_id,
  g.name as game_title,
  COUNT(*) as achievements_without_rarity
FROM achievements a
JOIN games g
  ON g.platform_id = a.platform_id
 AND g.platform_game_id = a.platform_game_id
WHERE a.platform_id IN (SELECT id FROM xbox_platforms)
  AND a.rarity_global IS NULL
  AND a.include_in_score = true
GROUP BY g.platform_game_id, g.name
ORDER BY achievements_without_rarity DESC
LIMIT 20;
