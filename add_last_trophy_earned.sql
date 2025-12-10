-- Add last_trophy_earned_at column to user_games
ALTER TABLE user_games
ADD COLUMN IF NOT EXISTS last_trophy_earned_at timestamptz;

-- Create index for sorting
CREATE INDEX IF NOT EXISTS idx_user_games_last_trophy ON user_games(last_trophy_earned_at DESC);

-- Backfill with existing data
-- Note: achievements.platform uses generic names (psn, xbox, steam) while platforms.code uses specific codes (PS4, PS5, XBOXONE, etc.)
UPDATE user_games ug
SET last_trophy_earned_at = (
  SELECT MAX(ua.earned_at)
  FROM user_achievements ua
  JOIN achievements a ON a.id = ua.achievement_id
  WHERE ua.user_id = ug.user_id
    AND a.game_title_id = ug.game_title_id
    AND (
      (a.platform = 'psn' AND (SELECT code FROM platforms WHERE id = ug.platform_id) IN ('PS3', 'PS4', 'PS5', 'PSVITA'))
      OR (a.platform = 'xbox' AND (SELECT code FROM platforms WHERE id = ug.platform_id) IN ('XBOXONE', 'XBOX360'))
      OR (LOWER(a.platform) = LOWER((SELECT code FROM platforms WHERE id = ug.platform_id)))
    )
);

COMMENT ON COLUMN user_games.last_trophy_earned_at IS 'Timestamp of the most recently earned trophy/achievement for this game';
