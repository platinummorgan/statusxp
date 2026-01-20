-- Check if games have cover_urls populated
SELECT 
  platform_id,
  platform_game_id,
  name,
  cover_url IS NOT NULL as has_cover_url,
  icon_url IS NOT NULL as has_icon_url,
  LEFT(cover_url, 50) as cover_url_sample,
  LEFT(icon_url, 50) as icon_url_sample
FROM games
WHERE name ILIKE '%call of duty%'
LIMIT 10;
