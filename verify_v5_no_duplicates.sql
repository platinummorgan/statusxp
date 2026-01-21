-- ============================================================================
-- Verify NO duplicates exist after cleanup v5
-- ============================================================================

-- Query 1: Check for any game_ids that still appear on multiple platforms
SELECT 
  platform_game_id,
  COUNT(DISTINCT platform_id) as platform_count,
  ARRAY_AGG(DISTINCT platform_id ORDER BY platform_id) as platforms,
  STRING_AGG(DISTINCT name, ' / ' ORDER BY name) as game_names
FROM games
WHERE platform_id IN (1, 2, 4, 5, 9, 10, 11, 12)
GROUP BY platform_game_id
HAVING COUNT(DISTINCT platform_id) > 1
ORDER BY platform_count DESC, platform_game_id;

-- Query 2: Overall stats
SELECT 
  (SELECT COUNT(*) FROM games WHERE platform_id IN (1,2,4,5,9,10,11,12)) as total_games,
  (SELECT COUNT(DISTINCT platform_game_id) FROM games WHERE platform_id IN (1,2,4,5,9,10,11,12)) as unique_game_ids,
  (SELECT COUNT(*) FROM games WHERE platform_id IN (1,2,4,5,9,10,11,12)) - 
  (SELECT COUNT(DISTINCT platform_game_id) FROM games WHERE platform_id IN (1,2,4,5,9,10,11,12)) as duplicates;

-- Query 3: Check Star Wars Jedi specifically (should be 0 rows)
SELECT 
  platform_id,
  platform_game_id,
  name,
  (SELECT COUNT(*) FROM user_achievements WHERE games.platform_id = user_achievements.platform_id AND games.platform_game_id = user_achievements.platform_game_id) as achievements_earned
FROM games
WHERE name ILIKE '%jedi%fallen%'
  AND platform_id IN (1, 2, 5)
ORDER BY platform_id;
