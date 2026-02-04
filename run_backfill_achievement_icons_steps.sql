-- STEP 1: Check how many achievements need backfilling
-- PlayStation platforms: 1, 2, 5, 9 (trophies table)
-- Xbox platforms: 10, 11, 12 (achievements table)

-- Check Xbox achievements
SELECT 
  'Xbox Achievements' as type,
  p.name as platform_name,
  COUNT(*) as icons_needing_backfill
FROM achievements a
JOIN platforms p ON p.id = a.platform_id
WHERE a.icon_url IS NOT NULL
  AND a.proxied_icon_url IS NULL
  AND a.platform_id IN (10, 11, 12)
GROUP BY p.name
ORDER BY COUNT(*) DESC;

-- Check PlayStation trophies
SELECT 
  'PlayStation Trophies' as type,
  p.name as platform_name,
  COUNT(*) as icons_needing_backfill
FROM trophies t
JOIN platforms p ON p.id = t.platform_id
WHERE t.icon_url IS NOT NULL
  AND t.proxied_icon_url IS NULL
  AND t.platform_id IN (1, 2, 5, 9)
GROUP BY p.name
ORDER BY COUNT(*) DESC;

-- STEP 2: Create storage bucket (if doesn't exist)
INSERT INTO storage.buckets (id, name, public) 
VALUES ('achievement-icons', 'achievement-icons', true)
ON CONFLICT (id) DO NOTHING;

-- STEP 3: Set storage bucket policy (allow public access)
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND policyname = 'Public Access achievement-icons') THEN
    CREATE POLICY "Public Access achievement-icons"
    ON storage.objects FOR SELECT
    USING ( bucket_id = 'achievement-icons' );
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND policyname = 'Service role can upload achievement-icons') THEN
    CREATE POLICY "Service role can upload achievement-icons"
    ON storage.objects FOR INSERT
    WITH CHECK ( bucket_id = 'achievement-icons' AND auth.role() = 'service_role' );
  END IF;
END $$;

-- STEP 4: After running the edge function via curl, verify results
-- Check Xbox achievements
SELECT 
  'Xbox Achievements' as type,
  p.name as platform_name,
  COUNT(*) as icons_with_supabase_urls
FROM achievements a
JOIN platforms p ON p.id = a.platform_id
WHERE a.proxied_icon_url LIKE '%supabase%'
  AND a.platform_id IN (10, 11, 12)
GROUP BY p.name
ORDER BY COUNT(*) DESC;

-- Check PlayStation trophies
SELECT 
  'PlayStation Trophies' as type,
  p.name as platform_name,
  COUNT(*) as icons_with_supabase_urls
FROM trophies t
JOIN platforms p ON p.id = t.platform_id
WHERE t.proxied_icon_url LIKE '%supabase%'
  AND t.platform_id IN (1, 2, 5, 9)
GROUP BY p.name
ORDER BY COUNT(*) DESC;
