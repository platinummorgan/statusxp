-- Migration: 016_populate_platforms_and_fix_sync.sql
-- Created: 2025-12-07
-- Description: Populate platforms table and backfill platform_id in user_games

-- ============================================================================
-- POPULATE PLATFORMS TABLE
-- ============================================================================
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

-- ============================================================================
-- BACKFILL PLATFORM_ID IN USER_GAMES
-- ============================================================================

-- For user_games that have a 'platform' column (old schema), update platform_id
-- This assumes you have a platform column in user_games temporarily
DO $$
DECLARE
  ps3_id bigint;
  ps4_id bigint;
  ps5_id bigint;
  psvita_id bigint;
  xbox360_id bigint;
  xboxone_id bigint;
  xboxseriesx_id bigint;
  steam_id bigint;
BEGIN
  -- Get platform IDs
  SELECT id INTO ps3_id FROM platforms WHERE code = 'PS3';
  SELECT id INTO ps4_id FROM platforms WHERE code = 'PS4';
  SELECT id INTO ps5_id FROM platforms WHERE code = 'PS5';
  SELECT id INTO psvita_id FROM platforms WHERE code = 'PSVITA';
  SELECT id INTO xbox360_id FROM platforms WHERE code = 'XBOX360';
  SELECT id INTO xboxone_id FROM platforms WHERE code = 'XBOXONE';
  SELECT id INTO xboxseriesx_id FROM platforms WHERE code = 'XBOXSERIESX';
  SELECT id INTO steam_id FROM platforms WHERE code = 'Steam';

  -- Update existing user_games records based on game_titles platform
  -- For PlayStation games (check if game_title has psn-related external_id or metadata)
  UPDATE user_games ug
  SET platform_id = CASE 
    WHEN gt.external_id LIKE 'NPWR%' OR gt.metadata->>'platform_group' = 'ps5' THEN ps5_id
    WHEN gt.external_id LIKE 'CUSA%' OR gt.metadata->>'platform_group' = 'ps4' THEN ps4_id
    WHEN gt.external_id LIKE 'NPUA%' OR gt.metadata->>'platform_group' = 'ps3' THEN ps3_id
    WHEN gt.metadata->>'platform_group' = 'psvita' THEN psvita_id
    ELSE ps4_id -- Default to PS4 for PSN games
  END
  FROM game_titles gt
  WHERE ug.game_title_id = gt.id
    AND ug.platform_id IS NULL
    AND (gt.external_id ~ '^(NPWR|CUSA|NPUA|PCSA|PCSE|NPXS)' 
         OR gt.metadata->>'psn_communication_id' IS NOT NULL);

  -- For Steam games: Default to Steam
  -- Note: We'll need to update sync services to set game_title metadata to identify platform
  
  -- For now, create a helper column to track which sync created the record
  ALTER TABLE user_games ADD COLUMN IF NOT EXISTS sync_platform text;
  
END $$;

-- ============================================================================
-- HELPER FUNCTION TO GET PLATFORM_ID
-- ============================================================================
CREATE OR REPLACE FUNCTION get_platform_id(platform_code text) 
RETURNS bigint AS $$
DECLARE
  pid bigint;
BEGIN
  SELECT id INTO pid FROM platforms WHERE code = platform_code;
  IF pid IS NULL THEN
    -- If platform doesn't exist, return PS4 as default (fallback)
    SELECT id INTO pid FROM platforms WHERE code = 'PS4' LIMIT 1;
  END IF;
  RETURN pid;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_platform_id IS 'Helper function to get platform ID from code, used by sync services';
