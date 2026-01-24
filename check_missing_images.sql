-- Check how many games have cover URLs
SELECT 
  COUNT(*) as total_games,
  COUNT(cover_url) as has_cover_url,
  COUNT(proxied_cover_url) as has_proxied_cover_url,
  COUNT(CASE WHEN cover_url IS NULL AND proxied_cover_url IS NULL THEN 1 END) as no_images
FROM game_titles;

-- Sample games with missing images
SELECT 
  id,
  name,
  cover_url,
  proxied_cover_url
FROM game_titles
WHERE proxied_cover_url IS NULL AND cover_url IS NULL
LIMIT 10;

-- Sample games with images
SELECT 
  id,
  name,
  cover_url,
  proxied_cover_url
FROM game_titles
WHERE proxied_cover_url IS NOT NULL OR cover_url IS NOT NULL
LIMIT 10;
