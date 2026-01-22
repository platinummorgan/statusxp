-- Add avatar URL columns for Xbox and Steam
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS xbox_avatar_url TEXT,
ADD COLUMN IF NOT EXISTS steam_avatar_url TEXT;

-- Add comment for documentation
COMMENT ON COLUMN profiles.xbox_avatar_url IS 'Xbox profile avatar URL fetched from Xbox Live API';
COMMENT ON COLUMN profiles.steam_avatar_url IS 'Steam avatar URL (avatarfull) fetched from Steam API';
