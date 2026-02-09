-- After creating the bucket, check what you already have
SELECT 
  COUNT(*) as total_with_urls,
  COUNT(CASE WHEN cover_url LIKE '%supabase%' OR cover_url LIKE '%cloudfront%' THEN 1 END) as already_uploaded,
  COUNT(CASE WHEN cover_url NOT LIKE '%supabase%' AND cover_url NOT LIKE '%cloudfront%' AND cover_url IS NOT NULL THEN 1 END) as need_upload
FROM games;
