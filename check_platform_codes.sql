-- Check what platform codes are returned for Steam games

SELECT 
  name,
  platforms,
  platform_ids
FROM grouped_games_cache
WHERE 4 = ANY(platform_ids)
LIMIT 5;
