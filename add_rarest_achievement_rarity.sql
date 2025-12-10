-- Add column to track rarest earned achievement rarity for sorting
ALTER TABLE user_games ADD COLUMN IF NOT EXISTS rarest_earned_achievement_rarity numeric;

-- Add index for efficient sorting
CREATE INDEX IF NOT EXISTS idx_user_games_rarest_rarity ON user_games(rarest_earned_achievement_rarity ASC NULLS LAST);

-- Backfill with existing data using proper platform matching
-- Note: achievements.platform uses generic names (psn, xbox, steam) while platforms.code uses specific codes
UPDATE user_games ug
SET rarest_earned_achievement_rarity = (
  SELECT MIN(a.rarity_global)
  FROM user_achievements ua
  JOIN achievements a ON a.id = ua.achievement_id
  WHERE ua.user_id = ug.user_id
    AND a.game_title_id = ug.game_title_id
    AND (
      (a.platform = 'psn' AND (SELECT code FROM platforms WHERE id = ug.platform_id) IN ('PS3', 'PS4', 'PS5', 'PSVITA'))
      OR (a.platform = 'xbox' AND (SELECT code FROM platforms WHERE id = ug.platform_id) IN ('XBOXONE', 'XBOX360'))
      OR (LOWER(a.platform) = LOWER((SELECT code FROM platforms WHERE id = ug.platform_id)))
    )
    AND a.rarity_global IS NOT NULL
);

COMMENT ON COLUMN user_games.rarest_earned_achievement_rarity IS 'The lowest rarity percentage among all earned achievements for this game (lower = rarer)';
