-- Check PSN trophy icons in storage
SELECT 
  name,
  bucket_id,
  created_at,
  metadata
FROM storage.objects 
WHERE bucket_id = 'avatars' 
  AND name LIKE 'achievement-icons/psn/%'
ORDER BY created_at DESC
LIMIT 10;

-- Check if trophies have proxied_icon_url populated
SELECT 
  id,
  name,
  icon_url,
  proxied_icon_url,
  created_at
FROM trophies
WHERE icon_url IS NOT NULL
ORDER BY created_at DESC
LIMIT 5;
