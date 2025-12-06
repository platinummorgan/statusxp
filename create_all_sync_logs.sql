-- Create Steam sync logs table
CREATE TABLE IF NOT EXISTS steam_sync_logs (
  id bigserial PRIMARY KEY,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  sync_type text NOT NULL CHECK (sync_type IN ('full', 'incremental')),
  status text NOT NULL CHECK (status IN ('pending', 'syncing', 'completed', 'failed')),
  started_at timestamptz NOT NULL,
  completed_at timestamptz,
  games_processed int DEFAULT 0,
  achievements_synced int DEFAULT 0,
  games_processed_ids text[] DEFAULT '{}',
  error_message text,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX idx_steam_sync_logs_user_id ON steam_sync_logs(user_id);
CREATE INDEX idx_steam_sync_logs_status ON steam_sync_logs(status);
CREATE INDEX idx_steam_sync_logs_started_at ON steam_sync_logs(started_at DESC);

-- Enable RLS
ALTER TABLE steam_sync_logs ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own sync logs
DROP POLICY IF EXISTS "Users can view own Steam sync logs" ON steam_sync_logs;
CREATE POLICY "Users can view own Steam sync logs"
  ON steam_sync_logs
  FOR SELECT
  USING (auth.uid() = user_id);

-- Policy: Users can insert their own sync logs
DROP POLICY IF EXISTS "Users can insert own Steam sync logs" ON steam_sync_logs;
CREATE POLICY "Users can insert own Steam sync logs"
  ON steam_sync_logs
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own sync logs
DROP POLICY IF EXISTS "Users can update own Steam sync logs" ON steam_sync_logs;
CREATE POLICY "Users can update own Steam sync logs"
  ON steam_sync_logs
  FOR UPDATE
  USING (auth.uid() = user_id);

-- Create PSN sync logs table
CREATE TABLE IF NOT EXISTS psn_sync_logs (
  id bigserial PRIMARY KEY,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  sync_type text NOT NULL CHECK (sync_type IN ('full', 'incremental')),
  status text NOT NULL CHECK (status IN ('pending', 'syncing', 'completed', 'failed')),
  started_at timestamptz NOT NULL,
  completed_at timestamptz,
  games_processed int DEFAULT 0,
  trophies_synced int DEFAULT 0,
  games_processed_ids text[] DEFAULT '{}',
  error_message text,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX idx_psn_sync_logs_user_id ON psn_sync_logs(user_id);
CREATE INDEX idx_psn_sync_logs_status ON psn_sync_logs(status);
CREATE INDEX idx_psn_sync_logs_started_at ON psn_sync_logs(started_at DESC);

-- Enable RLS
ALTER TABLE psn_sync_logs ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own sync logs
DROP POLICY IF EXISTS "Users can view own PSN sync logs" ON psn_sync_logs;
CREATE POLICY "Users can view own PSN sync logs"
  ON psn_sync_logs
  FOR SELECT
  USING (auth.uid() = user_id);

-- Policy: Users can insert their own sync logs
DROP POLICY IF EXISTS "Users can insert own PSN sync logs" ON psn_sync_logs;
CREATE POLICY "Users can insert own PSN sync logs"
  ON psn_sync_logs
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own sync logs
DROP POLICY IF EXISTS "Users can update own PSN sync logs" ON psn_sync_logs;
CREATE POLICY "Users can update own PSN sync logs"
  ON psn_sync_logs
  FOR UPDATE
  USING (auth.uid() = user_id);

-- Add games_processed_ids to Xbox sync logs (if not exists)
ALTER TABLE xbox_sync_logs 
ADD COLUMN IF NOT EXISTS games_processed_ids text[] DEFAULT '{}';

-- Add update policy for Xbox sync logs (if not exists)
DROP POLICY IF EXISTS "Users can update own Xbox sync logs" ON xbox_sync_logs;
CREATE POLICY "Users can update own Xbox sync logs"
  ON xbox_sync_logs
  FOR UPDATE
  USING (auth.uid() = user_id);
