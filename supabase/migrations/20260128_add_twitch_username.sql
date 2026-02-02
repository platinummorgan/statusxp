-- Add Twitch username/display name to profiles
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS twitch_username TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS twitch_display_name TEXT;

-- Add index for username lookups
CREATE INDEX IF NOT EXISTS idx_profiles_twitch_username ON profiles(twitch_username);
