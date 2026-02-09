-- Check what happened to "11-11 Memories Untold" game

-- Check if game exists in games table
SELECT 
  g.platform_id,
  g.platform_game_id,
  g.name,
  g.cover_url,
  p.code as platform_code
FROM games g
JOIN platforms p ON p.id = g.platform_id
WHERE g.name ILIKE '%11-11%'
ORDER BY g.platform_id;

-- Check if game appears in grouped_games_cache view
SELECT 
  name,
  cover_url,
  primary_platform_id,
  primary_game_id,
  platforms,
  platform_ids
FROM grouped_games_cache
WHERE name ILIKE '%11-11%';

-- Check normalized name
SELECT DISTINCT
  LOWER(TRIM(g.name)) as normalized_name,
  g.name as original_name,
  COUNT(*) as platform_count
FROM games g
WHERE g.name ILIKE '%11-11%'
GROUP BY LOWER(TRIM(g.name)), g.name;

-- Check if DISTINCT ON is filtering it out
SELECT 
  LOWER(TRIM(g.name)) AS normalized_name,
  g.name,
  g.platform_id,
  g.platform_game_id,
  g.cover_url
FROM games g
WHERE g.name ILIKE '%11-11%'
ORDER BY LOWER(TRIM(g.name)), g.platform_id, g.name;
