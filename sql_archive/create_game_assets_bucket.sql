-- Create game-assets bucket for achievement/game icons
INSERT INTO storage.buckets (id, name, public)
VALUES ('game-assets', 'game-assets', true)
ON CONFLICT (id) DO NOTHING;

-- Set up RLS policies for game-assets bucket
CREATE POLICY "Public read access for game assets"
ON storage.objects FOR SELECT
USING (bucket_id = 'game-assets');

CREATE POLICY "Authenticated users can upload game assets"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'game-assets'
  AND auth.role() = 'authenticated'
);

CREATE POLICY "Service role can manage game assets"
ON storage.objects FOR ALL
USING (bucket_id = 'game-assets')
WITH CHECK (bucket_id = 'game-assets');
