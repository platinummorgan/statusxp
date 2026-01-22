-- Migration: Add gamerscore column to xbox_leaderboard_cache and populate it
-- This fixes the Xbox leaderboard to show actual gamerscore instead of achievement count

-- Step 1: Add gamerscore column
ALTER TABLE xbox_leaderboard_cache 
ADD COLUMN IF NOT EXISTS gamerscore BIGINT DEFAULT 0;

-- Step 2: Populate with deduplicated gamerscore
UPDATE xbox_leaderboard_cache xlc
SET gamerscore = COALESCE(correct_gs.gamerscore, 0)
FROM (
  SELECT 
    user_id,
    SUM(max_gs) as gamerscore
  FROM (
    SELECT 
      ug.user_id,
      gt.name as game_name,
      MAX(ug.xbox_current_gamerscore) as max_gs
    FROM user_games ug
    INNER JOIN game_titles gt ON ug.game_title_id = gt.id
    INNER JOIN platforms pl ON ug.platform_id = pl.id
    WHERE pl.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')
    GROUP BY ug.user_id, gt.name
  ) deduplicated
  GROUP BY user_id
) correct_gs
WHERE xlc.user_id = correct_gs.user_id;

-- Step 3: Create index on gamerscore for leaderboard sorting
CREATE INDEX IF NOT EXISTS idx_xbox_leaderboard_cache_gamerscore 
  ON xbox_leaderboard_cache(gamerscore DESC, total_games DESC);

-- Step 4: Verify the fix
SELECT 
  display_name,
  gamerscore,
  achievement_count,
  total_games
FROM xbox_leaderboard_cache
WHERE gamerscore > 0
ORDER BY gamerscore DESC
LIMIT 10;
