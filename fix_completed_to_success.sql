-- Fix xbox_sync_status from 'completed' to 'success' to match Flutter app expectations
UPDATE profiles
SET xbox_sync_status = 'success'
WHERE xbox_sync_status = 'completed'
  AND xbox_user_hash IS NOT NULL;

-- Verify the change
SELECT 
  id,
  xbox_gamertag,
  xbox_sync_status,
  xbox_sync_progress,
  last_xbox_sync_at
FROM profiles
WHERE xbox_user_hash IS NOT NULL;
