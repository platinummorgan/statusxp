-- ============================================================================
-- Migration: 017_fix_cross_platform_game_titles.sql
-- Created: 2025-12-07
-- Description: Fix game_titles to be platform-agnostic for proper cross-platform tracking
-- ============================================================================

-- Step 1: Create new platform-agnostic game_titles structure
-- First, let's see what we're working with
DO $$
BEGIN
  RAISE NOTICE 'Starting cross-platform game_titles migration...';
END $$;

-- Step 2: Add a temporary column to track the canonical game_title_id
ALTER TABLE game_titles ADD COLUMN IF NOT EXISTS canonical_game_title_id bigint;

-- Step 3: For each game name, pick ONE canonical game_title (prefer PS5, then PS4, then others)
WITH ranked_games AS (
  SELECT 
    id,
    name,
    platform_id,
    ROW_NUMBER() OVER (
      PARTITION BY LOWER(TRIM(name)) 
      ORDER BY 
        CASE 
          WHEN p.code = 'PS5' THEN 1
          WHEN p.code = 'PS4' THEN 2
          WHEN p.code = 'PS3' THEN 3
          WHEN p.code = 'Steam' THEN 4
          WHEN p.code = 'XBOXONE' THEN 5
          ELSE 6
        END,
        id ASC
    ) as rank
  FROM game_titles gt
  LEFT JOIN platforms p ON gt.platform_id = p.id
)
UPDATE game_titles gt
SET canonical_game_title_id = (
  SELECT id 
  FROM ranked_games 
  WHERE LOWER(TRIM(ranked_games.name)) = LOWER(TRIM(gt.name)) 
    AND rank = 1
  LIMIT 1
);

-- Step 4: Update all user_games to point to canonical game_title
UPDATE user_games ug
SET game_title_id = gt.canonical_game_title_id
FROM game_titles gt
WHERE ug.game_title_id = gt.id
  AND gt.canonical_game_title_id IS NOT NULL
  AND gt.canonical_game_title_id != gt.id;

-- Step 5: Delete duplicate game_titles (keep only canonical ones)
DELETE FROM game_titles
WHERE id != canonical_game_title_id;

-- Step 6: Remove platform_id from game_titles (it should only be in user_games)
ALTER TABLE game_titles DROP COLUMN IF EXISTS platform_id;
ALTER TABLE game_titles DROP COLUMN IF EXISTS canonical_game_title_id;

-- Step 7: Update the unique constraint on game_titles (now just by name)
DROP INDEX IF EXISTS idx_game_titles_platform;
ALTER TABLE game_titles DROP CONSTRAINT IF EXISTS game_titles_platform_external_id_key;

-- Create unique constraint on name (case-insensitive)
CREATE UNIQUE INDEX IF NOT EXISTS idx_game_titles_name_unique 
  ON game_titles (LOWER(TRIM(name)));

-- Step 8: Verify the migration
DO $$
DECLARE
  total_games int;
  total_user_games int;
  games_with_multiple_platforms int;
BEGIN
  SELECT COUNT(*) INTO total_games FROM game_titles;
  SELECT COUNT(*) INTO total_user_games FROM user_games;
  SELECT COUNT(DISTINCT game_title_id) INTO games_with_multiple_platforms 
  FROM user_games 
  GROUP BY game_title_id 
  HAVING COUNT(DISTINCT platform_id) > 1;
  
  RAISE NOTICE 'Migration complete!';
  RAISE NOTICE 'Total unique games: %', total_games;
  RAISE NOTICE 'Total user_games records: %', total_user_games;
  RAISE NOTICE 'Games owned on multiple platforms: %', games_with_multiple_platforms;
END $$;
