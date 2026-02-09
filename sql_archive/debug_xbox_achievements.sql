-- Debug Xbox achievements issue
-- Let's check what data we actually have for a specific Xbox game

-- 1. Check if we have any Xbox games
SELECT platform_id, platform_game_id, name 
FROM games 
WHERE platform_id IN (10, 11, 12)
LIMIT 5;

-- 2. Pick a specific game and check achievements
-- Using a common game that should have achievements
SELECT 
  g.platform_id,
  g.platform_game_id,
  g.name,
  COUNT(a.platform_achievement_id) as achievement_count
FROM games g
LEFT JOIN achievements a ON 
  a.platform_id = g.platform_id 
  AND a.platform_game_id = g.platform_game_id
WHERE g.platform_id IN (10, 11, 12)
  AND g.name ILIKE '%halo%'
GROUP BY g.platform_id, g.platform_game_id, g.name
LIMIT 10;

-- 3. Check what the browse function actually returns for Xbox
SELECT 
  name,
  primary_platform_id,
  primary_game_id,
  total_achievements
FROM get_grouped_games_fast(NULL, 'xbox', 20, 0)
WHERE total_achievements > 0
LIMIT 10;

-- 4. For a specific game, check achievements across all Xbox platforms
WITH game_name AS (
  SELECT name FROM games WHERE platform_id = 11 LIMIT 1
)
SELECT 
  g.platform_id,
  g.platform_game_id,
  g.name,
  COUNT(a.platform_achievement_id) as achievement_count
FROM games g
LEFT JOIN achievements a ON 
  a.platform_id = g.platform_id 
  AND a.platform_game_id = g.platform_game_id
WHERE g.name = (SELECT name FROM game_name)
  AND g.platform_id IN (10, 11, 12)
GROUP BY g.platform_id, g.platform_game_id, g.name;
