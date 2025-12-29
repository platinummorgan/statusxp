-- Migration: Add platform_version to achievements table
-- This allows PS4/PS5/Xbox360/XboxOne versions to be distinguished

-- Add the column
ALTER TABLE achievements
ADD COLUMN IF NOT EXISTS platform_version TEXT;

-- Create index for efficient lookups
CREATE INDEX IF NOT EXISTS idx_achievements_platform_version 
ON achievements(game_title_id, platform, platform_version);

-- Populate platform_version based on user_games data
-- For achievements that users have earned, tag them with the platform version

-- PS4 achievements
UPDATE achievements a
SET platform_version = 'PS4'
WHERE platform_version IS NULL
  AND platform = 'psn'
  AND EXISTS (
    SELECT 1 FROM user_achievements ua
    JOIN user_games ug ON ua.user_id = ug.user_id AND a.game_title_id = ug.game_title_id
    JOIN platforms p ON ug.platform_id = p.id
    WHERE ua.achievement_id = a.id
    AND p.code = 'PS4'
  );

-- PS5 achievements  
UPDATE achievements a
SET platform_version = 'PS5'
WHERE platform_version IS NULL
  AND platform = 'psn'
  AND EXISTS (
    SELECT 1 FROM user_achievements ua
    JOIN user_games ug ON ua.user_id = ug.user_id AND a.game_title_id = ug.game_title_id
    JOIN platforms p ON ug.platform_id = p.id
    WHERE ua.achievement_id = a.id
    AND p.code = 'PS5'
  );

-- PS3 achievements
UPDATE achievements a
SET platform_version = 'PS3'
WHERE platform_version IS NULL
  AND platform = 'psn'
  AND EXISTS (
    SELECT 1 FROM user_achievements ua
    JOIN user_games ug ON ua.user_id = ug.user_id AND a.game_title_id = ug.game_title_id
    JOIN platforms p ON ug.platform_id = p.id
    WHERE ua.achievement_id = a.id
    AND p.code = 'PS3'
  );

-- Xbox achievements
UPDATE achievements a
SET platform_version = 'XBOXONE'
WHERE platform_version IS NULL
  AND platform = 'xbox'
  AND EXISTS (
    SELECT 1 FROM user_achievements ua
    WHERE ua.achievement_id = a.id
  );

-- Steam achievements
UPDATE achievements a
SET platform_version = 'STEAM'
WHERE platform_version IS NULL
  AND platform = 'steam';

-- Verify results
SELECT 
    platform,
    platform_version,
    COUNT(*) as achievement_count
FROM achievements
GROUP BY platform, platform_version
ORDER BY platform, platform_version;
