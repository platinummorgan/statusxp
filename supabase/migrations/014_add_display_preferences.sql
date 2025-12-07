-- Migration: 014_add_display_preferences.sql
-- Created: 2025-12-06
-- Description: Add user display preferences for cross-platform dashboard

-- Add preferred display platform to profiles
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS preferred_display_platform text DEFAULT 'psn' CHECK (preferred_display_platform IN ('psn', 'steam', 'xbox'));

-- Add Steam display name to profiles (if not already exists from 001_create_core_tables.sql)
-- Note: steam_id already exists, but we need steam_display_name for the actual username
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS steam_display_name text;

-- Add comments
COMMENT ON COLUMN profiles.preferred_display_platform IS 'Platform to use for display name in dashboard (psn, steam, or xbox)';
COMMENT ON COLUMN profiles.steam_display_name IS 'Steam display name/username';
