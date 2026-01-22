-- Add sync error tracking to user_games table
-- This prevents data inconsistency where user_games shows has_platinum=true
-- but no achievement records exist because trophy fetch failed

ALTER TABLE user_games 
ADD COLUMN IF NOT EXISTS sync_failed BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS sync_error TEXT,
ADD COLUMN IF NOT EXISTS last_sync_attempt TIMESTAMPTZ;

-- Create index for finding failed syncs
CREATE INDEX IF NOT EXISTS idx_user_games_sync_failed 
ON user_games(user_id, sync_failed) 
WHERE sync_failed = TRUE;

-- Add comment
COMMENT ON COLUMN user_games.sync_failed IS 'True if the last trophy sync attempt failed for this game';
COMMENT ON COLUMN user_games.sync_error IS 'Error message from last failed sync attempt';
COMMENT ON COLUMN user_games.last_sync_attempt IS 'Timestamp of last sync attempt (successful or failed)';
