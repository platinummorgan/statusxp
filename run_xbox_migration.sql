-- Safe Xbox Integration Migration
-- Run this in Supabase SQL Editor to add Xbox columns

-- Add Xbox columns to profiles (safe with IF NOT EXISTS equivalent)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='profiles' AND column_name='xbox_xuid') THEN
    ALTER TABLE profiles ADD COLUMN xbox_xuid text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='profiles' AND column_name='xbox_gamertag') THEN
    ALTER TABLE profiles ADD COLUMN xbox_gamertag text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='profiles' AND column_name='xbox_access_token') THEN
    ALTER TABLE profiles ADD COLUMN xbox_access_token text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='profiles' AND column_name='xbox_refresh_token') THEN
    ALTER TABLE profiles ADD COLUMN xbox_refresh_token text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='profiles' AND column_name='xbox_token_expires_at') THEN
    ALTER TABLE profiles ADD COLUMN xbox_token_expires_at timestamptz;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='profiles' AND column_name='last_xbox_sync_at') THEN
    ALTER TABLE profiles ADD COLUMN last_xbox_sync_at timestamptz;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='profiles' AND column_name='xbox_sync_status') THEN
    ALTER TABLE profiles ADD COLUMN xbox_sync_status text DEFAULT 'never_synced' CHECK (xbox_sync_status IN ('never_synced', 'pending', 'syncing', 'success', 'error'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='profiles' AND column_name='xbox_sync_error') THEN
    ALTER TABLE profiles ADD COLUMN xbox_sync_error text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='profiles' AND column_name='xbox_sync_progress') THEN
    ALTER TABLE profiles ADD COLUMN xbox_sync_progress int DEFAULT 0;
  END IF;
END $$;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_profiles_xbox_xuid ON profiles(xbox_xuid) WHERE xbox_xuid IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_profiles_xbox_sync_status ON profiles(xbox_sync_status);
CREATE INDEX IF NOT EXISTS idx_profiles_xbox_gamertag ON profiles(xbox_gamertag) WHERE xbox_gamertag IS NOT NULL;

-- Add Xbox columns to game_titles
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='game_titles' AND column_name='xbox_title_id') THEN
    ALTER TABLE game_titles ADD COLUMN xbox_title_id bigint;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='game_titles' AND column_name='xbox_service_config_id') THEN
    ALTER TABLE game_titles ADD COLUMN xbox_service_config_id text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='game_titles' AND column_name='xbox_product_id') THEN
    ALTER TABLE game_titles ADD COLUMN xbox_product_id text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='game_titles' AND column_name='xbox_max_gamerscore') THEN
    ALTER TABLE game_titles ADD COLUMN xbox_max_gamerscore int;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='game_titles' AND column_name='xbox_total_achievements') THEN
    ALTER TABLE game_titles ADD COLUMN xbox_total_achievements int;
  END IF;
END $$;

-- Create indexes for game_titles
CREATE INDEX IF NOT EXISTS idx_game_titles_xbox_title_id ON game_titles(xbox_title_id) WHERE xbox_title_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_game_titles_xbox_product_id ON game_titles(xbox_product_id) WHERE xbox_product_id IS NOT NULL;

-- Add Xbox columns to user_games
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_games' AND column_name='xbox_progress_data') THEN
    ALTER TABLE user_games ADD COLUMN xbox_progress_data jsonb DEFAULT '{}'::jsonb;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_games' AND column_name='xbox_last_updated_at') THEN
    ALTER TABLE user_games ADD COLUMN xbox_last_updated_at timestamptz;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_games' AND column_name='xbox_current_gamerscore') THEN
    ALTER TABLE user_games ADD COLUMN xbox_current_gamerscore int DEFAULT 0;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_games' AND column_name='xbox_max_gamerscore') THEN
    ALTER TABLE user_games ADD COLUMN xbox_max_gamerscore int DEFAULT 0;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_games' AND column_name='xbox_achievements_earned') THEN
    ALTER TABLE user_games ADD COLUMN xbox_achievements_earned int DEFAULT 0;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_games' AND column_name='xbox_total_achievements') THEN
    ALTER TABLE user_games ADD COLUMN xbox_total_achievements int DEFAULT 0;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_user_games_xbox_progress ON user_games USING gin(xbox_progress_data);

-- Create xbox_sync_log table
CREATE TABLE IF NOT EXISTS xbox_sync_log (
  id bigserial PRIMARY KEY,
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  sync_type text NOT NULL CHECK (sync_type IN ('full', 'incremental', 'single_game')),
  status text NOT NULL CHECK (status IN ('started', 'in_progress', 'completed', 'failed')),
  games_processed int DEFAULT 0,
  games_total int DEFAULT 0,
  achievements_added int DEFAULT 0,
  achievements_updated int DEFAULT 0,
  error_message text,
  started_at timestamptz DEFAULT now(),
  completed_at timestamptz,
  metadata jsonb DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_xbox_sync_log_user ON xbox_sync_log(user_id, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_xbox_sync_log_status ON xbox_sync_log(status, started_at DESC);

-- Enable RLS on xbox_sync_log
ALTER TABLE xbox_sync_log ENABLE ROW LEVEL SECURITY;

-- RLS policies for xbox_sync_log
DROP POLICY IF EXISTS "Users can view their own Xbox sync logs" ON xbox_sync_log;
CREATE POLICY "Users can view their own Xbox sync logs"
  ON xbox_sync_log FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own Xbox sync logs" ON xbox_sync_log;
CREATE POLICY "Users can insert their own Xbox sync logs"
  ON xbox_sync_log FOR INSERT
  WITH CHECK (auth.uid() = user_id);
