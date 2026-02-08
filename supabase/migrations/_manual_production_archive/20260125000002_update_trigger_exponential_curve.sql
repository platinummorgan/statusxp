-- Migration: Update trigger function to use exponential curve
-- Date: 2026-01-25
-- Purpose: Update calculate_achievement_statusxp() trigger to use exponential curve
--          Formula: base = 0.5 + (12 - 0.5) * (1 - rarity_global/100)^3

BEGIN;

-- Replace trigger function with exponential curve formula
CREATE OR REPLACE FUNCTION public.calculate_achievement_statusxp()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  -- Only calculate if we include in score (platinums excluded)
  IF NEW.include_in_score = false THEN
    NEW.base_status_xp := 0;
    RETURN NEW;
  END IF;

  -- Default for unknown rarity (treat as common)
  IF NEW.rarity_global IS NULL THEN
    NEW.base_status_xp := 0.5;
    RETURN NEW;
  END IF;

  -- Exponential curve: base = 0.5 + (12 - 0.5) * (1 - rarity_global/100)^3
  NEW.base_status_xp := GREATEST(0.5, 
    LEAST(12.0, 
      0.5 + (12.0 - 0.5) * POWER(
        GREATEST(0, LEAST(1, 1 - (NEW.rarity_global / 100.0))),
        3
      )
    )
  );

  RETURN NEW;
END;
$$;

COMMIT;
