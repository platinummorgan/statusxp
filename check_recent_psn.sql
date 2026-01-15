-- Show recent PSN achievements to see if NEW ones have proxied URLs
SELECT 
  id,
  name,
  platform,
  CASE 
    WHEN proxied_icon_url IS NOT NULL THEN '✅ HAS PROXY'
    ELSE '❌ NO PROXY'
  END as proxy_status,
  LEFT(icon_url, 50) as icon_url_preview,
  LEFT(proxied_icon_url, 50) as proxied_preview,
  created_at
FROM achievements
WHERE platform = 'psn'
  AND icon_url IS NOT NULL
ORDER BY created_at DESC
LIMIT 20;
