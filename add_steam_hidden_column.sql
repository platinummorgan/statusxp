-- Add steam_hidden column to achievements table
ALTER TABLE achievements
ADD COLUMN IF NOT EXISTS steam_hidden BOOLEAN DEFAULT FALSE;
