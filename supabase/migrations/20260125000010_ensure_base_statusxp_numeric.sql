-- Migration: Ensure base_status_xp supports decimals for exponential curve
-- Date: 2026-01-25

BEGIN;

ALTER TABLE public.achievements
  ALTER COLUMN base_status_xp TYPE numeric(6,2)
  USING base_status_xp::numeric;

COMMIT;
