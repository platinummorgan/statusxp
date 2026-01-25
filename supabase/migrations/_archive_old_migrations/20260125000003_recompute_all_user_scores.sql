-- Migration: Recompute all user scores after exponential curve update
-- Date: 2026-01-25
-- Purpose: Recalculate all user_progress.current_score using new base_status_xp values
--          Now that base has exponential curve and multipliers are 1.0

BEGIN;

-- Recompute current_score for all user progress records
-- Formula: SUM(base_status_xp * rarity_multiplier) per game (multiplier now = 1.0)
UPDATE public.user_progress up
SET current_score = COALESCE(calc.total_score, 0)
FROM (
  SELECT 
    ua.user_id,
    ua.platform_id,
    ua.platform_game_id,
    ROUND(SUM(a.base_status_xp * a.rarity_multiplier))::integer AS total_score
  FROM public.user_achievements ua
  JOIN public.achievements a
    ON a.platform_id = ua.platform_id
   AND a.platform_game_id = ua.platform_game_id
   AND a.platform_achievement_id = ua.platform_achievement_id
  WHERE a.include_in_score = true
  GROUP BY ua.user_id, ua.platform_id, ua.platform_game_id
) calc
WHERE up.user_id = calc.user_id
  AND up.platform_id = calc.platform_id
  AND up.platform_game_id = calc.platform_game_id;

COMMIT;
