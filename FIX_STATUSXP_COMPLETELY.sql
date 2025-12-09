-- COMPLETE FIX: Update achievements AND recalculate game totals
-- Run this in one go to fix everything

-- Step 1: Update all achievements to use the correct base_status_xp values (10-30)
UPDATE achievements
SET base_status_xp = CASE
    WHEN include_in_score = false THEN 0
    WHEN rarity_global IS NULL THEN 10
    WHEN rarity_global > 25 THEN 10
    WHEN rarity_global > 10 THEN 13
    WHEN rarity_global > 5 THEN 18
    WHEN rarity_global > 1 THEN 23
    ELSE 30
END
WHERE rarity_global IS NOT NULL;

-- Step 2: Fix the calculation function
DROP FUNCTION IF EXISTS calculate_user_game_statusxp() CASCADE;

CREATE OR REPLACE FUNCTION calculate_user_game_statusxp()
RETURNS void AS $$
BEGIN
  WITH game_statusxp AS (
    SELECT 
      ug.id as user_game_id,
      COALESCE(SUM(a.base_status_xp), 0) as raw_xp,
      COUNT(*) FILTER (WHERE a.is_dlc = false AND ua.id IS NOT NULL) as base_unlocked,
      COUNT(*) FILTER (WHERE a.is_dlc = false) as base_total
    FROM public.user_games ug
    CROSS JOIN LATERAL (
      SELECT code as platform_code FROM public.platforms WHERE id = ug.platform_id
    ) p
    LEFT JOIN public.achievements a ON a.game_title_id = ug.game_title_id 
      AND (
        (a.platform = 'psn' AND p.platform_code IN ('PS3', 'PS4', 'PS5', 'PSVITA')) OR
        (a.platform = 'xbox' AND p.platform_code LIKE '%XBOX%') OR
        (a.platform = 'steam' AND p.platform_code = 'Steam')
      )
    LEFT JOIN public.user_achievements ua ON ua.achievement_id = a.id AND ua.user_id = ug.user_id
    GROUP BY ug.id
  )
  UPDATE public.user_games ug
  SET 
    statusxp_raw = gs.raw_xp::integer,
    base_completed = (gs.base_total > 0 AND gs.base_unlocked = gs.base_total),
    statusxp_effective = (gs.raw_xp * stack_multiplier)::integer
  FROM game_statusxp gs
  WHERE ug.id = gs.user_game_id;
END;
$$ LANGUAGE plpgsql;

-- Step 3: Run the recalculation
SELECT calculate_user_game_statusxp();

-- Step 4: Verify the fix
SELECT
  COUNT(*) as total_games,
  SUM(statusxp_effective) as total_statusxp,
  AVG(statusxp_effective) as avg_per_game,
  MAX(statusxp_effective) as highest_game
FROM user_games
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Step 5: Check 11-11 specifically
SELECT
  gt.name,
  ug.statusxp_raw,
  ug.statusxp_effective,
  ug.earned_trophies
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
WHERE gt.name ILIKE '%11-11%'
  AND ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';
