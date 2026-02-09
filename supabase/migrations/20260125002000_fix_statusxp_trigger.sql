-- Fix StatusXP trigger and recalc for all achievements
-- Date: 2026-01-25

BEGIN;
-- Remove legacy banded trigger/function that overwrites exponential curve
DROP TRIGGER IF EXISTS trigger_achievement_rarity ON public.achievements;
DROP FUNCTION IF EXISTS public.trigger_update_achievement_rarity();
-- Normalize rarity_multiplier (currently fixed at 1.0)
UPDATE public.achievements
SET rarity_multiplier = 1.0
WHERE rarity_multiplier IS DISTINCT FROM 1.0;
-- Recalculate base_status_xp using exponential curve
UPDATE public.achievements
SET base_status_xp = LEAST(12, GREATEST(0.5, 0.5 + 11.5 * POWER(1 - (rarity_global / 100.0), 3)))
WHERE rarity_global IS NOT NULL;
-- Default for missing rarity
UPDATE public.achievements
SET base_status_xp = 0.5
WHERE rarity_global IS NULL;
COMMIT;
