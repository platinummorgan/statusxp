-- Add is_platinum column to achievements table for V2 schema
-- This column distinguishes PSN platinum trophies (which don't count for StatusXP)
-- from regular achievements

-- Add the column if it doesn't exist
ALTER TABLE achievements 
ADD COLUMN IF NOT EXISTS is_platinum BOOLEAN DEFAULT false;

-- Add the include_in_score column if it doesn't exist (determines if achievement counts toward StatusXP)
ALTER TABLE achievements
ADD COLUMN IF NOT EXISTS include_in_score BOOLEAN DEFAULT true;

-- Add the proxied_icon_url column if it doesn't exist (stores Supabase Storage URLs for proxied achievement icons)
ALTER TABLE achievements
ADD COLUMN IF NOT EXISTS proxied_icon_url TEXT;

-- Update existing PSN achievements that are platinums
-- Platinum trophies have psn_trophy_type = 'platinum'
UPDATE achievements
SET is_platinum = true
WHERE 
  platform = 'psn'
  AND psn_trophy_type = 'platinum';

-- Mark platinum trophies as excluded from score (they don't contribute to StatusXP)
UPDATE achievements
SET include_in_score = false
WHERE 
  platform = 'psn'
  AND psn_trophy_type = 'platinum';

-- Verify the update
SELECT 
  platform,
  COUNT(*) as total_achievements,
  COUNT(*) FILTER (WHERE is_platinum = true) as platinum_count,
  COUNT(*) FILTER (WHERE include_in_score = false) as excluded_from_score
FROM achievements
GROUP BY platform
ORDER BY platform;
