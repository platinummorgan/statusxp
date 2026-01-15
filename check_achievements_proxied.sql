-- Check if achievements have proxied_icon_url populated for PSN
SELECT 
  id,
  name,
  platform,
  icon_url,
  proxied_icon_url,
  created_at
FROM achievements
WHERE platform = 'psn'
  AND icon_url IS NOT NULL
ORDER BY created_at DESC
LIMIT 10;

-- Count how many PSN achievements have proxied URLs vs don't
SELECT 
  COUNT(*) as total_psn_achievements,
  COUNT(proxied_icon_url) as with_proxied_url,
  COUNT(*) - COUNT(proxied_icon_url) as without_proxied_url
FROM achievements
WHERE platform = 'psn'
  AND icon_url IS NOT NULL;
