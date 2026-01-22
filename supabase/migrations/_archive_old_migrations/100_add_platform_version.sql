-- Migration: Add platform_version tracking to game_titles
-- This allows PS4/PS5/Xbox360/XboxOne/etc versions to be separate entries

-- Step 1: Add the column
ALTER TABLE game_titles 
ADD COLUMN IF NOT EXISTS platform_version TEXT;

-- Step 2: Create index for efficient lookups
CREATE INDEX IF NOT EXISTS idx_game_titles_name_version 
ON game_titles(name, platform_version);

-- Step 3: Populate platform_version for existing games based on their achievements
-- Games with only PS3 achievements
UPDATE game_titles gt
SET platform_version = 'PS3'
WHERE platform_version IS NULL
  AND EXISTS (
    SELECT 1 FROM achievements a
    WHERE a.game_title_id = gt.id
    AND a.platform = 'psn'
  )
  AND EXISTS (
    SELECT 1 FROM user_games ug
    JOIN platforms p ON ug.platform_id = p.id
    WHERE ug.game_title_id = gt.id
    AND p.code = 'PS3'
  )
  AND NOT EXISTS (
    SELECT 1 FROM user_games ug
    JOIN platforms p ON ug.platform_id = p.id
    WHERE ug.game_title_id = gt.id
    AND p.code IN ('PS4', 'PS5')
  );

-- Games with only PS4 achievements
UPDATE game_titles gt
SET platform_version = 'PS4'
WHERE platform_version IS NULL
  AND EXISTS (
    SELECT 1 FROM user_games ug
    JOIN platforms p ON ug.platform_id = p.id
    WHERE ug.game_title_id = gt.id
    AND p.code = 'PS4'
  );

-- Games with only PS5 achievements
UPDATE game_titles gt
SET platform_version = 'PS5'
WHERE platform_version IS NULL
  AND EXISTS (
    SELECT 1 FROM user_games ug
    JOIN platforms p ON ug.platform_id = p.id
    WHERE ug.game_title_id = gt.id
    AND p.code = 'PS5'
  );

-- Games with Xbox achievements
UPDATE game_titles gt
SET platform_version = 'XBOXONE'
WHERE platform_version IS NULL
  AND EXISTS (
    SELECT 1 FROM achievements a
    WHERE a.game_title_id = gt.id
    AND a.platform = 'xbox'
  );

-- Games with Steam achievements
UPDATE game_titles gt
SET platform_version = 'STEAM'
WHERE platform_version IS NULL
  AND EXISTS (
    SELECT 1 FROM achievements a
    WHERE a.game_title_id = gt.id
    AND a.platform = 'steam'
  );

-- Verify results
SELECT 
    platform_version,
    COUNT(*) as game_count
FROM game_titles
GROUP BY platform_version
ORDER BY game_count DESC;
