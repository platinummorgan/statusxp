-- Add platform-specific game IDs to enforce 1 game_title = 1 platform rule
-- This prevents duplicate game entries and enables proper sync upsert logic
-- NOTE: UNIQUE constraints will be added AFTER cleaning up duplicates

-- Add platform ID columns
ALTER TABLE game_titles
  ADD COLUMN psn_npwr_id TEXT,
  ADD COLUMN xbox_title_id TEXT,
  ADD COLUMN steam_app_id TEXT;

-- Add indexes for faster lookups during sync (but NOT UNIQUE yet)
CREATE INDEX idx_game_titles_psn_npwr_id ON game_titles(psn_npwr_id);
CREATE INDEX idx_game_titles_xbox_title_id ON game_titles(xbox_title_id);
CREATE INDEX idx_game_titles_steam_app_id ON game_titles(steam_app_id);

-- Add comment documenting the new architecture rule
COMMENT ON TABLE game_titles IS 'Each game_title entry represents ONE platform version of a game. Use psn_npwr_id, xbox_title_id, or steam_app_id to identify and prevent duplicates.';
