-- Check if avatars bucket exists and its configuration
SELECT 
  id,
  name,
  public,
  created_at
FROM storage.buckets 
WHERE name = 'avatars';

-- Check if any achievement icons have been uploaded
SELECT 
  name,
  bucket_id,
  created_at,
  metadata
FROM storage.objects 
WHERE bucket_id = 'avatars' 
  AND name LIKE 'achievement-icons/%'
ORDER BY created_at DESC
LIMIT 5;
