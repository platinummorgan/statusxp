-- Add premium_source column to track where premium came from
-- Values: 'apple', 'google', 'stripe', 'twitch'
ALTER TABLE user_premium_status 
ADD COLUMN IF NOT EXISTS premium_source TEXT;
-- Add index for efficient filtering
CREATE INDEX IF NOT EXISTS idx_user_premium_status_source 
ON user_premium_status(premium_source) 
WHERE premium_source IS NOT NULL;
-- Add comment
COMMENT ON COLUMN user_premium_status.premium_source IS 
'Source of premium subscription: apple, google, stripe, or twitch. Used for hierarchy and conflict resolution.';
