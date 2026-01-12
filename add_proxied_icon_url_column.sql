-- Add proxied_icon_url column to achievements table to fix CORS issues
-- PlayStation's image API blocks cross-origin requests from browsers

ALTER TABLE achievements
ADD COLUMN IF NOT EXISTS proxied_icon_url text;

COMMENT ON COLUMN achievements.proxied_icon_url IS 'Proxied trophy/achievement icon URL stored in Supabase Storage (fixes CORS)';

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_achievements_proxied_icon ON achievements(proxied_icon_url) WHERE proxied_icon_url IS NOT NULL;

-- Also add to legacy trophies table for compatibility
ALTER TABLE trophies
ADD COLUMN IF NOT EXISTS proxied_icon_url text;

COMMENT ON COLUMN trophies.proxied_icon_url IS 'Proxied trophy icon URL stored in Supabase Storage (fixes CORS)';

CREATE INDEX IF NOT EXISTS idx_trophies_proxied_icon ON trophies(proxied_icon_url) WHERE proxied_icon_url IS NOT NULL;
