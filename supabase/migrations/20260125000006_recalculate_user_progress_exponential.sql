-- Migration: Recalculate all user_progress.current_score using exponential curve
-- Date: 2026-01-25
-- 
-- Problem: user_progress.current_score has old banded StatusXP values (132k for user)
-- Solution: Recalculate all scores using exponential curve formula from achievements
--
-- This will update ALL users' StatusXP to reflect the exponential curve:
-- base = 0.5 + (12-0.5) * (1-rarity/100)^3

BEGIN;

UPDATE public.user_progress up
SET current_score = COALESCE(calc.total_score, 0)
FROM (
  SELECT 
    ua.user_id,
    ua.platform_id,
    ua.platform_game_id,
    ROUND(SUM(a.base_status_xp * a.rarity_multiplier))::integer AS total_score
  FROM public.user_achievements ua
  JOIN public.achievements a ON 
    a.platform_id = ua.platform_id
    AND a.platform_game_id = ua.platform_game_id
    AND a.platform_achievement_id = ua.platform_achievement_id
  WHERE a.include_in_score = true  -- Exclude platinums
  GROUP BY ua.user_id, ua.platform_id, ua.platform_game_id
) calc
WHERE up.user_id = calc.user_id
  AND up.platform_id = calc.platform_id
  AND up.platform_game_id = calc.platform_game_id;

COMMIT;

-- Verify the fix worked
SELECT 
  'After recalculation' as check_point,
  COUNT(*) as games_updated,
  SUM(current_score) as total_statusxp,
  AVG(current_score) as avg_statusxp_per_game
FROM user_progress
WHERE current_score > 0;
