-- Add trophy breakdown columns to user_games table
ALTER TABLE user_games
  ADD COLUMN IF NOT EXISTS bronze_trophies INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS silver_trophies INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS gold_trophies INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS platinum_trophies INT DEFAULT 0;

COMMENT ON COLUMN user_games.bronze_trophies IS 'Number of bronze trophies earned for this game';
COMMENT ON COLUMN user_games.silver_trophies IS 'Number of silver trophies earned for this game';
COMMENT ON COLUMN user_games.gold_trophies IS 'Number of gold trophies earned for this game';
COMMENT ON COLUMN user_games.platinum_trophies IS 'Number of platinum trophies earned for this game';
