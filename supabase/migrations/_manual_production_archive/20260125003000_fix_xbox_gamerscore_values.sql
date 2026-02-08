-- Fix Xbox gamerscore anomalies (cap invalid values)
-- Date: 2026-01-25

BEGIN;

-- Zero out invalid per-achievement gamerscore values (Xbox achievements are typically 5-200)
UPDATE public.achievements
SET score_value = 0
WHERE platform_id IN (10,11,12)
  AND (score_value < 0 OR score_value > 200);

-- Backfill missing/zero score_value from metadata.gamerscore when it is valid
UPDATE public.achievements
SET score_value = (metadata->>'gamerscore')::int
WHERE platform_id IN (10,11,12)
  AND (score_value IS NULL OR score_value = 0)
  AND (metadata->>'gamerscore') ~ '^[0-9]+$'
  AND (metadata->>'gamerscore')::int BETWEEN 0 AND 200;

COMMIT;
