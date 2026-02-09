-- Check what URLs are actually in your database
SELECT 
  platform_id,
  platform_game_id,
  name,
  cover_url,
  CASE 
    WHEN cover_url LIKE '%supabase%' THEN 'Supabase Storage'
    WHEN cover_url LIKE '%cloudfront%' THEN 'CloudFront CDN'
    WHEN cover_url LIKE '%psnobj%' THEN 'PSN External'
    WHEN cover_url LIKE '%xbox%' THEN 'Xbox External'
    WHEN cover_url LIKE '%steam%' THEN 'Steam External'
    ELSE 'Other External'
  END as url_type
FROM games
WHERE cover_url IS NOT NULL
LIMIT 20;
