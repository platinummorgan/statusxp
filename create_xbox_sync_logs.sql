-- Create Xbox sync logs table
CREATE TABLE IF NOT EXISTS xbox_sync_logs (
  id bigserial PRIMARY KEY,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  sync_type text NOT NULL CHECK (sync_type IN ('full', 'incremental')),
  status text NOT NULL CHECK (status IN ('pending', 'syncing', 'completed', 'failed')),
  started_at timestamptz NOT NULL,
  completed_at timestamptz,
  games_processed int DEFAULT 0,
  achievements_synced int DEFAULT 0,
  error_message text,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX idx_xbox_sync_logs_user_id ON xbox_sync_logs(user_id);
CREATE INDEX idx_xbox_sync_logs_status ON xbox_sync_logs(status);
CREATE INDEX idx_xbox_sync_logs_started_at ON xbox_sync_logs(started_at DESC);

-- Enable RLS
ALTER TABLE xbox_sync_logs ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own sync logs
DROP POLICY IF EXISTS "Users can view own Xbox sync logs" ON xbox_sync_logs;
CREATE POLICY "Users can view own Xbox sync logs"
  ON xbox_sync_logs
  FOR SELECT
  USING (auth.uid() = user_id);

-- Policy: Users can insert their own sync logs
DROP POLICY IF EXISTS "Users can insert own Xbox sync logs" ON xbox_sync_logs;
CREATE POLICY "Users can insert own Xbox sync logs"
  ON xbox_sync_logs
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);
