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
