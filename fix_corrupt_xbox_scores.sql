-- Fix corrupt Xbox achievement score_values
-- Some achievements have absurdly high values (21M+ instead of typical max 1000)

BEGIN;

-- 1. Fix: Use metadata gamerscore if available, cap at 1000, or delete if completely corrupt
UPDATE achievements
SET score_value = CASE
  WHEN metadata->>'gamerscore' IS NOT NULL 
    THEN (metadata->>'gamerscore')::int
  ELSE LEAST(score_value, 1000)
END
WHERE platform_id IN (10, 11, 12)
  AND score_value > 1000;

-- 2. Delete the completely corrupt achievement (no metadata gamerscore and 21.9M value)
-- "Successor of the Azure" in game 461173340 is clearly broken
DELETE FROM user_achievements
WHERE platform_id = 11
  AND platform_game_id = '461173340'
  AND platform_achievement_id = '123';  -- Successor of the Azure

DELETE FROM achievements
WHERE platform_id = 11
  AND platform_game_id = '461173340'
  AND platform_achievement_id = '123';

-- 3. Verify fix
SELECT 
  'After fix' as check_point,
  COUNT(*) as total_xbox_achievements,
  MAX(score_value) as new_max_score,
  MIN(score_value) as new_min_score
FROM achievements
WHERE platform_id IN (10, 11, 12);

-- 4. Verify Otaku's corrected gamerscore
SELECT 
  SUM(a.score_value) as corrected_gamerscore,
  COUNT(*) as achievement_count
FROM user_achievements ua
JOIN achievements a ON 
  a.platform_id = ua.platform_id
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = '1dab84fc-e06c-44b6-ae34-7e36a5179583'
  AND ua.platform_id IN (10, 11, 12);

COMMIT;
