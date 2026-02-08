-- Migration: Switch to exponential curve for base_status_xp
-- Date: 2026-01-25
-- Purpose: Replace banded scoring (5/7/9/12/15) with continuous exponential curve
--          Formula: base = 0.5 + (12 - 0.5) * (1 - rarity_global/100)^3
--          Set all rarity_multiplier to 1.0 to avoid double-counting rarity
--          Keep platinums at base_status_xp = 0

BEGIN;

-- Update all achievements with exponential curve formula
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
  END,
  rarity_multiplier = 1.0  -- Eliminate multipliers to avoid double-counting
WHERE true;

COMMIT;
