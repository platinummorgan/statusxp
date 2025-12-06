-- Add Xbox columns to profiles table
ALTER TABLE profiles 
  ADD COLUMN IF NOT EXISTS xbox_xuid text,
  ADD COLUMN IF NOT EXISTS xbox_gamertag text,
  ADD COLUMN IF NOT EXISTS xbox_access_token text,
  ADD COLUMN IF NOT EXISTS xbox_refresh_token text,
  ADD COLUMN IF NOT EXISTS xbox_token_expires_at timestamptz,
  ADD COLUMN IF NOT EXISTS xbox_sync_status text DEFAULT 'never_synced';
