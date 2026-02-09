-- Migration: Change base_status_xp to numeric to support exponential curve decimals
-- Date: 2026-01-25
-- Purpose: Change base_status_xp from integer to numeric so exponential curve
--          can store decimal values (e.g., 8.88 instead of truncating to 9)

BEGIN;
-- Change column type from integer to numeric
ALTER TABLE public.achievements 
  ALTER COLUMN base_status_xp TYPE numeric USING base_status_xp::numeric;
-- Re-apply exponential curve formula now that column supports decimals
UPDATE public.achievements
SET 
  base_status_xp = CASE
    WHEN include_in_score = false THEN 0  -- Platinums stay 0
    WHEN rarity_global IS NULL THEN 0.5   -- NULL rarity treated as common
    ELSE 
      -- Exponential curve: 0.5 + (12 - 0.5) * (1 - rarity_global/100)^3
      GREATEST(0.5, 
        LEAST(12.0, 
          0.5 + (12.0 - 0.5) * POWER(
            GREATEST(0, LEAST(1, 1 - (rarity_global / 100.0))),
            3
          )
        )
      )
  END
WHERE true;
-- Recompute all user scores with new decimal base values
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
