-- Run this migration manually in Supabase SQL Editor
-- Migration: 014_add_display_preferences.sql

-- Add preferred display platform to profiles
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS preferred_display_platform text DEFAULT 'psn' CHECK (preferred_display_platform IN ('psn', 'steam', 'xbox'));

-- Add Steam display name to profiles
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS steam_display_name text;

-- Add comments
COMMENT ON COLUMN profiles.preferred_display_platform IS 'Platform to use for display name in dashboard (psn, steam, or xbox)';
COMMENT ON COLUMN profiles.steam_display_name IS 'Steam display name/username';

-- Verify the changes
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'profiles'
AND column_name IN ('preferred_display_platform', 'steam_display_name');
