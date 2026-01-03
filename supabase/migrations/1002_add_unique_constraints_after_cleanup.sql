-- Add UNIQUE constraints on platform IDs
-- Run this AFTER duplicates have been cleaned up

-- Add UNIQUE constraints (NULL values are allowed and don't conflict with each other)
-- This prevents the same PSN/Xbox/Steam game from being inserted twice
CREATE UNIQUE INDEX game_titles_psn_npwr_id_unique 
  ON game_titles(psn_npwr_id) 
  WHERE psn_npwr_id IS NOT NULL;

CREATE UNIQUE INDEX game_titles_xbox_title_id_unique 
  ON game_titles(xbox_title_id) 
  WHERE xbox_title_id IS NOT NULL;

CREATE UNIQUE INDEX game_titles_steam_app_id_unique 
  ON game_titles(steam_app_id) 
  WHERE steam_app_id IS NOT NULL;

-- Verify constraints were created
DO $$
BEGIN
  RAISE NOTICE 'UNIQUE constraints added successfully';
  RAISE NOTICE 'Future syncs will prevent duplicate game entries per platform';
END $$;
