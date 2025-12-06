-- Add games_processed_ids array column to track which games have been processed in a sync session
ALTER TABLE xbox_sync_logs 
ADD COLUMN IF NOT EXISTS games_processed_ids text[] DEFAULT '{}';

-- Add comment
COMMENT ON COLUMN xbox_sync_logs.games_processed_ids IS 'Array of Xbox title IDs that have been processed in this sync session';
