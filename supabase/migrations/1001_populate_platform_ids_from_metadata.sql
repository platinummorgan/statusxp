-- Migrate platform IDs from metadata jsonb to dedicated columns
-- This preserves all existing platform ID data before we update sync code

-- Populate psn_npwr_id from metadata
UPDATE game_titles
SET psn_npwr_id = metadata->>'psn_np_communication_id'
WHERE metadata->>'psn_np_communication_id' IS NOT NULL
  AND psn_npwr_id IS NULL;

-- Populate xbox_title_id from metadata
UPDATE game_titles
SET xbox_title_id = metadata->>'xbox_title_id'
WHERE metadata->>'xbox_title_id' IS NOT NULL
  AND xbox_title_id IS NULL;

-- Populate steam_app_id from metadata
UPDATE game_titles
SET steam_app_id = metadata->>'steam_app_id'
WHERE metadata->>'steam_app_id' IS NOT NULL
  AND steam_app_id IS NULL;

-- Verify migration results
DO $$
DECLARE
  psn_count INT;
  xbox_count INT;
  steam_count INT;
BEGIN
  SELECT COUNT(*) INTO psn_count FROM game_titles WHERE psn_npwr_id IS NOT NULL;
  SELECT COUNT(*) INTO xbox_count FROM game_titles WHERE xbox_title_id IS NOT NULL;
  SELECT COUNT(*) INTO steam_count FROM game_titles WHERE steam_app_id IS NOT NULL;
  
  RAISE NOTICE 'Platform ID migration complete:';
  RAISE NOTICE '  PSN games: %', psn_count;
  RAISE NOTICE '  Xbox games: %', xbox_count;
  RAISE NOTICE '  Steam games: %', steam_count;
END $$;
