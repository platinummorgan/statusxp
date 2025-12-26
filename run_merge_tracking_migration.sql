-- Run this in Supabase SQL Editor to add account merge tracking

ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS merged_into_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS merged_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_profiles_merged_into ON profiles(merged_into_user_id) WHERE merged_into_user_id IS NOT NULL;

COMMENT ON COLUMN profiles.merged_into_user_id IS 'If this account was merged into another, this is the target user ID';
COMMENT ON COLUMN profiles.merged_at IS 'Timestamp when this account was merged';
