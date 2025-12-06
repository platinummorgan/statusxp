-- Add Steam sync status columns to profiles table
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS steam_api_key text,
ADD COLUMN IF NOT EXISTS steam_sync_status text,
ADD COLUMN IF NOT EXISTS steam_sync_progress integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS steam_sync_error text,
ADD COLUMN IF NOT EXISTS last_steam_sync_at timestamptz;

-- Add Steam achievement columns to game_titles
ALTER TABLE game_titles
ADD COLUMN IF NOT EXISTS steam_app_id integer UNIQUE,
ADD COLUMN IF NOT EXISTS steam_total_achievements integer DEFAULT 0;

-- Add Steam achievement columns to user_games  
ALTER TABLE user_games
ADD COLUMN IF NOT EXISTS steam_achievements_earned integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS steam_total_achievements integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS steam_last_updated_at timestamptz;

-- Create index for Steam app lookups
CREATE INDEX IF NOT EXISTS idx_game_titles_steam_app_id ON game_titles(steam_app_id);
