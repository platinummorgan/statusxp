-- Check full cover URL format
SELECT 
  platform_id,
  name,
  cover_url,
  LENGTH(cover_url) as url_length
FROM games
WHERE cover_url IS NOT NULL
LIMIT 5;
