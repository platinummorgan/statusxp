-- Add index to speed up achievement similarity calculations
CREATE INDEX IF NOT EXISTS idx_achievements_game_title_name 
ON achievements(game_title_id, LOWER(TRIM(name)));

-- Also add index on just game_title_id if it doesn't exist
CREATE INDEX IF NOT EXISTS idx_achievements_game_title_id 
ON achievements(game_title_id);
