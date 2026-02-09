-- STEP 1: Check how many games need backfilling
-- PlayStation platforms: 1, 2, 5, 9
-- Xbox platforms: 10, 11, 12

SELECT 
  p.name as platform_name,
  COUNT(*) as games_needing_backfill
FROM games g
JOIN platforms p ON p.id = g.platform_id
WHERE g.cover_url IS NOT NULL
  AND g.cover_url NOT LIKE '%supabase%'
  AND g.cover_url NOT LIKE '%cloudfront%'
  AND g.platform_id IN (1, 2, 5, 9, 10, 11, 12)
GROUP BY p.name
ORDER BY COUNT(*) DESC;

-- STEP 2: Create storage bucket (if doesn't exist)
INSERT INTO storage.buckets (id, name, public) 
VALUES ('game-covers', 'game-covers', true)
ON CONFLICT (id) DO NOTHING;

-- STEP 3: Set storage bucket policy (allow public access)
-- Skip if policies already exist (you'll get an error if they do)
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND policyname = 'Public Access') THEN
    CREATE POLICY "Public Access"
    ON storage.objects FOR SELECT
    USING ( bucket_id = 'game-covers' );
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND policyname = 'Service role can upload') THEN
    CREATE POLICY "Service role can upload"
    ON storage.objects FOR INSERT
    WITH CHECK ( bucket_id = 'game-covers' AND auth.role() = 'service_role' );
  END IF;
END $$;

-- STEP 4: After running the edge function via curl, verify results
SELECT 
  p.name as platform_name,
  COUNT(*) as games_with_supabase_urls
FROM games g
JOIN platforms p ON p.id = g.platform_id
WHERE g.cover_url LIKE '%supabase%'
  AND g.platform_id IN (1, 2, 5, 9, 10, 11, 12)
GROUP BY p.name
ORDER BY COUNT(*) DESC;
