-- Check games table structure
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'games' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check if games table has proxied URLs or just cover URLs  
SELECT 
  COUNT(*) as total_games,
  COUNT(cover_url) as has_cover_url,
  COUNT(CASE WHEN cover_url LIKE '%cloudfront%' OR cover_url LIKE '%supabase%' THEN 1 END) as has_proxied_urls,
  COUNT(CASE WHEN cover_url NOT LIKE '%cloudfront%' AND cover_url NOT LIKE '%supabase%' AND cover_url IS NOT NULL THEN 1 END) as has_external_urls
FROM games;

-- Sample external URLs that need proxying
SELECT platform_id, platform_game_id, name, cover_url
FROM games
WHERE cover_url IS NOT NULL
  AND cover_url NOT LIKE '%cloudfront%'
  AND cover_url NOT LIKE '%supabase%'
LIMIT 10;
