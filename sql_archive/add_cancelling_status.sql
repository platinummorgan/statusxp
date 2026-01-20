-- Add 'cancelling' status to sync status constraints
-- This allows the stop sync functionality to work properly

-- PSN sync status
ALTER TABLE profiles 
  DROP CONSTRAINT IF EXISTS profiles_psn_sync_status_check;

ALTER TABLE profiles 
  ADD CONSTRAINT profiles_psn_sync_status_check 
  CHECK (psn_sync_status IN ('never_synced', 'pending', 'syncing', 'success', 'error', 'stopped', 'cancelling'));

COMMENT ON CONSTRAINT profiles_psn_sync_status_check ON profiles IS 
  'Valid PSN sync statuses: never_synced (initial), pending (more to sync), syncing (active), success (complete), error (failed), stopped (paused by user), cancelling (stop requested)';

-- Xbox sync status
ALTER TABLE profiles 
  DROP CONSTRAINT IF EXISTS profiles_xbox_sync_status_check;

ALTER TABLE profiles 
  ADD CONSTRAINT profiles_xbox_sync_status_check 
  CHECK (xbox_sync_status IN ('never_synced', 'pending', 'syncing', 'success', 'error', 'stopped', 'cancelling'));

COMMENT ON CONSTRAINT profiles_xbox_sync_status_check ON profiles IS 
  'Valid Xbox sync statuses: never_synced (initial), pending (more to sync), syncing (active), success (complete), error (failed), stopped (paused by user), cancelling (stop requested)';

-- Steam sync status  
ALTER TABLE profiles 
  DROP CONSTRAINT IF EXISTS profiles_steam_sync_status_check;

ALTER TABLE profiles 
  ADD CONSTRAINT profiles_steam_sync_status_check 
  CHECK (steam_sync_status IN ('never_synced', 'pending', 'syncing', 'success', 'error', 'stopped', 'cancelling'));

COMMENT ON CONSTRAINT profiles_steam_sync_status_check ON profiles IS 
  'Valid Steam sync statuses: never_synced (initial), pending (more to sync), syncing (active), success (complete), error (failed), stopped (paused by user), cancelling (stop requested)';
