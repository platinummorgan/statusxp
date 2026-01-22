-- Add last_rarity_sync column to user_games table
ALTER TABLE user_games
ADD COLUMN last_rarity_sync TIMESTAMPTZ;

-- Set initial value to now for existing rows (so they won't all refresh at once)
UPDATE user_games
SET last_rarity_sync = NOW()
WHERE last_rarity_sync IS NULL;
