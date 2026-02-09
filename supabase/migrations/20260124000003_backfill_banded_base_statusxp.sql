-- Migration: Backfill banded base_status_xp values across all achievements
-- Date: 2026-01-24
-- Purpose: Ensure all achievements use discrete banded base values (5/7/9/12/15)
--          per rarity ranges and exclude PSN platinums from scoring.

BEGIN;
-- Exclude PSN platinums from scoring explicitly (safety)
UPDATE public.achievements
SET include_in_score = false,
    base_status_xp   = 0
WHERE platform_id IN (1,2,5,9)
  AND COALESCE((metadata->>'psn_trophy_type')::text, '') = 'platinum';
-- Backfill banded base values for all other achievements
UPDATE public.achievements
SET base_status_xp = CASE
    WHEN include_in_score = false THEN 0
    WHEN rarity_global IS NULL THEN 5
    WHEN rarity_global > 25 THEN 5   -- COMMON
    WHEN rarity_global > 10 THEN 7   -- UNCOMMON
    WHEN rarity_global > 5  THEN 9   -- RARE
    WHEN rarity_global > 1  THEN 12  -- VERY_RARE
    ELSE 15                          -- ULTRA_RARE
  END
WHERE true;
-- Optional: normalize rarity_multiplier again (idempotent)
UPDATE public.achievements
SET rarity_multiplier = CASE
    WHEN include_in_score = false THEN 0.00
    WHEN rarity_global IS NULL THEN 1.00
    WHEN rarity_global > 25 THEN 1.00
    WHEN rarity_global > 10 THEN 1.25
    WHEN rarity_global > 5 THEN 1.75
    WHEN rarity_global > 1 THEN 2.25
    ELSE 3.00
  END;
COMMIT;
