-- Populate max_score in user_progress metadata for potential StatusXP calculation
-- This calculates the maximum possible StatusXP per game based on achievement values

-- Step 1: Check the user_progress table structure
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'user_progress' 
ORDER BY ordinal_position;

-- Step 2: Check achievements table structure
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'achievements' 
ORDER BY ordinal_position;

-- Step 3: Sample data from user_progress
SELECT *
FROM user_progress
LIMIT 3;

-- Step 4: Calculate max possible StatusXP per game
WITH game_max_scores AS (
  SELECT 
    platform_id,
    platform_game_id,
    SUM(base_status_xp) as max_score
  FROM achievements
  WHERE include_in_score = true
  GROUP BY platform_id, platform_game_id
)
SELECT 
  platform_id,
  platform_game_id,
  max_score
FROM game_max_scores
ORDER BY max_score DESC
LIMIT 10;

-- Step 5: Update user_progress to add max_score to metadata
-- This enables potential StatusXP calculations in the leaderboard
UPDATE user_progress up
SET metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object('max_score', ROUND(COALESCE(gms.max_score, 0))::text)
FROM (
  SELECT 
    platform_id,
    platform_game_id,
    SUM(base_status_xp) as max_score
  FROM achievements
  WHERE include_in_score = true
  GROUP BY platform_id, platform_game_id
) gms
WHERE up.platform_id = gms.platform_id 
  AND up.platform_game_id = gms.platform_game_id;

-- Step 6: Verify the update
SELECT 
  up.user_id,
  up.platform_id,
  up.platform_game_id,
  up.current_score as current,
  (up.metadata->>'max_score')::numeric as max_possible
FROM user_progress up
WHERE (up.metadata->>'max_score') IS NOT NULL
  AND (up.metadata->>'max_score')::numeric > 0
LIMIT 20;

