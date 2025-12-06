-- Add games_processed_ids to Steam sync logs
ALTER TABLE steam_sync_logs 
ADD COLUMN IF NOT EXISTS games_processed_ids text[] DEFAULT '{}';

COMMENT ON COLUMN steam_sync_logs.games_processed_ids IS 'Array of Steam App IDs that have been processed in this sync session';

-- Add games_processed_ids to PSN sync logs  
ALTER TABLE psn_sync_logs
ADD COLUMN IF NOT EXISTS games_processed_ids text[] DEFAULT '{}';

COMMENT ON COLUMN psn_sync_logs.games_processed_ids IS 'Array of PSN np_communication_ids that have been processed in this sync session';
