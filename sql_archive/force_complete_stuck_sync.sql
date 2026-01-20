-- Force complete a stuck sync for a user
-- Use this when Railway shows 100% but app is still polling

-- Replace 'USER_ID_HERE' with the actual user ID
-- You can find it by searching for the user's gamertag in the profiles table

UPDATE profiles 
SET 
  xbox_sync_status = 'success',
  xbox_sync_progress = 100,
  last_xbox_sync_at = NOW()
WHERE id = 'USER_ID_HERE';

-- Verify the update
SELECT 
  id,
  xbox_gamertag,
  xbox_sync_status,
  xbox_sync_progress,
  last_xbox_sync_at
FROM profiles 
WHERE id = 'USER_ID_HERE';
