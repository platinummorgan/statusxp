-- Reset Steam sync status to allow retry
UPDATE profiles
SET 
  steam_sync_status = NULL,
  steam_sync_progress = 0,
  steam_sync_error = NULL
WHERE id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Verify reset
SELECT steam_sync_status, steam_sync_progress, steam_sync_error
FROM profiles
WHERE id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';
