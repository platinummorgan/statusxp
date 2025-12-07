-- ============================================================================
-- CRITICAL FIX: Populate platforms table and backfill user_games
-- Run this in Supabase SQL Editor NOW to fix Xbox/Steam showing as "unknown"
-- ============================================================================

-- Step 1: Add platforms if they don't exist
INSERT INTO platforms (code, name, primary_color, accent_color)
VALUES 
  ('PS3', 'PlayStation 3', '#00A8E1', '#0070CC'),
  ('PS4', 'PlayStation 4', '#00A8E1', '#0070CC'),
  ('PS5', 'PlayStation 5', '#00A8E1', '#0070CC'),
  ('PSVITA', 'PlayStation Vita', '#00A8E1', '#0070CC'),
  ('XBOX360', 'Xbox 360', '#107C10', '#0E6B0E'),
  ('XBOXONE', 'Xbox One', '#107C10', '#0E6B0E'),
  ('XBOXSERIESX', 'Xbox Series X|S', '#107C10', '#0E6B0E'),
  ('Steam', 'Steam', '#66C0F4', '#1B2838')
ON CONFLICT (code) DO NOTHING;

-- Step 2: Add unique constraint to game_titles if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'game_titles_platform_external_id_key'
  ) THEN
    ALTER TABLE game_titles 
    ADD CONSTRAINT game_titles_platform_external_id_key 
    UNIQUE (platform_id, external_id);
  END IF;
END $$;

-- Step 3: Add unique constraint to user_games if it doesn't exist  
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'user_games_user_game_platform_key'
  ) THEN
    ALTER TABLE user_games 
    ADD CONSTRAINT user_games_user_game_platform_key 
    UNIQUE (user_id, game_title_id, platform_id);
  END IF;
END $$;

-- DONE! Now you need to re-sync Xbox and Steam to populate with correct platform codes.
-- The sync services have been updated and deployed to Railway.
