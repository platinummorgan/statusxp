-- Check if proxied_icon_url is being populated
SELECT 
  COUNT(*) as total_trophies,
  COUNT(proxied_icon_url) as proxied_count,
  COUNT(*) - COUNT(proxied_icon_url) as missing_proxied
FROM trophies
WHERE icon_url IS NOT NULL;

-- Show sample of recent trophies with/without proxied URLs
SELECT 
  id,
  name,
  icon_url,
  proxied_icon_url,
  created_at
FROM trophies
ORDER BY created_at DESC
LIMIT 10;
