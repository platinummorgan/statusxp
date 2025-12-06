-- Add missing Xbox sync columns to profiles table
ALTER TABLE profiles 
  ADD COLUMN IF NOT EXISTS last_xbox_sync_at timestamptz,
  ADD COLUMN IF NOT EXISTS xbox_sync_error text,
  ADD COLUMN IF NOT EXISTS xbox_sync_progress int DEFAULT 0;

-- Create indexes if they don't exist
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_profiles_last_xbox_sync') THEN
    CREATE INDEX idx_profiles_last_xbox_sync ON profiles(last_xbox_sync_at DESC) WHERE last_xbox_sync_at IS NOT NULL;
  END IF;
END $$;
