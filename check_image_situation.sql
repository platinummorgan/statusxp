-- ROLLBACK: Revert to external URLs since storage files don't exist yet
-- This will make mobile apps work again while we fix the storage upload

-- First check what we have
SELECT 
  COUNT(*) as total,
  COUNT(CASE WHEN cover_url LIKE '%supabase%' THEN 1 END) as supabase_urls,
  COUNT(CASE WHEN cover_url IS NULL THEN 1 END) as null_urls
FROM games;

-- Note: We can't automatically revert because the original external URLs are gone
-- You'll need to re-sync or restore from a backup
