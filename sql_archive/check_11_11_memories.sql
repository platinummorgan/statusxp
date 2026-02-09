-- Check 11-11 Memories Retold game data

-- First, find all games with this name
SELECT 
  g.platform_id,
  p.name as platform_name,
  p.code as platform_code,
  g.platform_game_id,
  g.name,
  g.cover_url,
  g.created_at
FROM games g
JOIN platforms p ON p.id = g.platform_id
WHERE g.name ILIKE '%11-11%memories%'
ORDER BY g.platform_id;

-- Check achievements for these games
SELECT 
  a.platform_id,
  p.name as platform_name,
  a.platform_game_id,
  COUNT(*) as achievement_count
FROM achievements a
JOIN platforms p ON p.id = a.platform_id
WHERE a.platform_game_id IN (
  SELECT DISTINCT platform_game_id 
  FROM games 
  WHERE name ILIKE '%11-11%memories%'
)
GROUP BY a.platform_id, p.name, a.platform_game_id
ORDER BY a.platform_id;

-- Check the normalized name grouping
SELECT 
  LOWER(TRIM(g.name)) as normalized_name,
  g.platform_id,
  p.code as platform_code,
  g.platform_game_id,
  g.name
FROM games g
JOIN platforms p ON p.id = g.platform_id
WHERE g.name ILIKE '%11-11%memories%'
ORDER BY LOWER(TRIM(g.name)), g.platform_id;

-- Check if it's in the materialized view
SELECT 
  name,
  primary_platform_id,
  primary_game_id,
  platforms,
  platform_names,
  platform_ids,
  platform_game_ids
FROM grouped_games_cache
WHERE name ILIKE '%11-11%memories%';
