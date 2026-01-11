-- Test query to see which games are using proxied vs external cover URLs
SELECT 
  id,
  name,
  CASE 
    WHEN proxied_cover_url IS NOT NULL THEN 'Proxied (Supabase Storage)'
    WHEN cover_url LIKE '%supabase%' THEN 'Already Proxied'
    WHEN cover_url IS NOT NULL THEN 'External (needs migration)'
    ELSE 'No cover'
  END as cover_status,
  COALESCE(proxied_cover_url, cover_url) as display_url
FROM game_titles
ORDER BY id DESC
LIMIT 20;

-- Count of games by cover status
SELECT 
  CASE 
    WHEN proxied_cover_url IS NOT NULL THEN 'Proxied'
    WHEN cover_url LIKE '%supabase%' THEN 'Already Proxied in cover_url'
    WHEN cover_url IS NOT NULL THEN 'External URL'
    ELSE 'No cover'
  END as status,
  COUNT(*) as count
FROM game_titles
GROUP BY 
  CASE 
    WHEN proxied_cover_url IS NOT NULL THEN 'Proxied'
    WHEN cover_url LIKE '%supabase%' THEN 'Already Proxied in cover_url'
    WHEN cover_url IS NOT NULL THEN 'External URL'
    ELSE 'No cover'
  END
ORDER BY count DESC;
