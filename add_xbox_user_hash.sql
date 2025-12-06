-- Add xbox_user_hash column for proper API authorization
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS xbox_user_hash text;

COMMENT ON COLUMN profiles.xbox_user_hash IS 'Xbox Live user hash (uhs) required for API authorization headers';
