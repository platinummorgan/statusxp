-- Add proxied_cover_url column to game_titles table
-- This will store Supabase Storage URLs instead of external CDN URLs to avoid CORS issues

ALTER TABLE game_titles 
ADD COLUMN IF NOT EXISTS proxied_cover_url TEXT;

COMMENT ON COLUMN game_titles.proxied_cover_url IS 'Game cover URL proxied through Supabase Storage to avoid CORS issues on web';

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_game_titles_proxied_cover_url 
ON game_titles(proxied_cover_url) 
WHERE proxied_cover_url IS NOT NULL;
