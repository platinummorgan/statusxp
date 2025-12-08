-- Add rarity_last_updated_at to achievements table
ALTER TABLE achievements 
ADD COLUMN IF NOT EXISTS rarity_last_updated_at TIMESTAMPTZ;

-- Set today's date for all existing Xbox achievements with rarity
UPDATE achievements 
SET rarity_last_updated_at = NOW()
WHERE platform = 'xbox' 
  AND rarity_global IS NOT NULL;
