-- Migration: Default NULL Xbox rarity to COMMON (50%)
-- Date: 2026-01-25

BEGIN;
WITH xbox_platforms AS (
  SELECT id
  FROM public.platforms
  WHERE code ILIKE 'xbox%'
     OR name ILIKE 'xbox%'
)
UPDATE public.achievements a
SET
  rarity_global = 50.0,
  rarity_multiplier = 1.0,
  base_status_xp = ROUND(0.5 + 11.5 * POWER(1 - 0.5, 3), 2)
WHERE a.platform_id IN (SELECT id FROM xbox_platforms)
  AND a.rarity_global IS NULL
  AND a.include_in_score = true;
COMMIT;
