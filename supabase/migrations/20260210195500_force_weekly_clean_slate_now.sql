-- Force immediate weekly clean slate from migration execution time.
-- Keeps Tuesday weekly cadence override active until 2026-02-17 UTC.

BEGIN;

INSERT INTO public.seasonal_period_overrides (period_type, start_at, end_at, note, updated_at)
VALUES (
  'weekly',
  now(),
  '2026-02-17 00:00:00+00',
  'Immediate clean slate reset',
  now()
)
ON CONFLICT (period_type)
DO UPDATE SET
  start_at = EXCLUDED.start_at,
  end_at = EXCLUDED.end_at,
  note = EXCLUDED.note,
  updated_at = now();

COMMIT;

