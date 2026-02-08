-- Add Twitch integration support to profiles table
-- Allows users to link Twitch accounts for subscription-based premium access

ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS twitch_user_id TEXT;

-- Add index for faster lookups when EventSub webhooks fire
CREATE INDEX IF NOT EXISTS idx_profiles_twitch_user_id 
ON profiles(twitch_user_id) 
WHERE twitch_user_id IS NOT NULL;

-- Add comment explaining the column
COMMENT ON COLUMN profiles.twitch_user_id IS 'Twitch user ID (not username) for linking Twitch subscriptions to premium access';

-- Add premium_source column to track where premium came from
ALTER TABLE user_premium_status
ADD COLUMN IF NOT EXISTS premium_source TEXT;

-- Add expires_at column (used by Twitch integration for 30+3 day subscriptions)
ALTER TABLE user_premium_status
ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;

-- Add comment explaining premium_source
COMMENT ON COLUMN user_premium_status.premium_source IS 'Source of premium subscription: twitch, apple, google, stripe, or null for non-premium';
COMMENT ON COLUMN user_premium_status.expires_at IS 'When premium expires (used for Twitch 33-day subscriptions with grace period)';
