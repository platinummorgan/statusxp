BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '120s';

CREATE OR REPLACE FUNCTION public.calculate_achievement_statusxp()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO public, pg_temp
AS $$
DECLARE
  completion_rarity_weight numeric := 1;
BEGIN
  -- Enforce Platinum scoring for installed sync versions that still exclude it.
  IF NEW.platform_id IN (1, 2, 5, 9)
    AND (NEW.is_platinum OR NEW.metadata->>'psn_trophy_type' = 'platinum') THEN
    completion_rarity_weight := 5;
    NEW.is_platinum := true;
    NEW.include_in_score := true;
    NEW.rarity_multiplier := 1.0;
  END IF;

  IF NEW.include_in_score = false THEN
    NEW.base_status_xp := 0;
    RETURN NEW;
  END IF;

  IF NEW.rarity_global IS NULL THEN
    NEW.base_status_xp := 0.5;
    RETURN NEW;
  END IF;

  NEW.base_status_xp := greatest(0.5, least(0.5 + 11.5 * completion_rarity_weight,
    0.5 + 11.5 * completion_rarity_weight * power(greatest(0, least(1, 1 - NEW.rarity_global / 100.0)), 3)
  ));
  RETURN NEW;
END;
$$;

-- Existing catalog rarity is the native PlayStation trophy percentage.
UPDATE public.achievements
SET is_platinum = true,
    include_in_score = true,
    rarity_multiplier = 1.0
WHERE platform_id IN (1, 2, 5, 9)
  AND (is_platinum OR metadata->>'psn_trophy_type' = 'platinum')
  AND (
    is_platinum IS DISTINCT FROM true
    OR include_in_score IS DISTINCT FROM true
    OR rarity_multiplier IS DISTINCT FROM 1.0
    OR base_status_xp IS DISTINCT FROM CASE
      WHEN rarity_global IS NULL THEN 0.5
      ELSE round(greatest(0.5, least(58.0,
        0.5 + 11.5 * 5 * power(greatest(0, least(1, 1 - rarity_global / 100.0)), 3)
      )), 2)
    END
  );

-- Publish earned and potential totals atomically with the scoring change.
SELECT public.refresh_statusxp_leaderboard();

DO $$
BEGIN
  ASSERT NOT EXISTS (
    SELECT 1 FROM public.achievements
    WHERE platform_id IN (1, 2, 5, 9)
      AND (is_platinum OR metadata->>'psn_trophy_type' = 'platinum')
      AND (is_platinum IS DISTINCT FROM true
        OR include_in_score IS DISTINCT FROM true
        OR rarity_multiplier IS DISTINCT FROM 1.0
        OR base_status_xp IS DISTINCT FROM CASE
          WHEN rarity_global IS NULL THEN 0.5
          ELSE round(greatest(0.5, least(58.0,
            0.5 + 11.5 * 5 * power(greatest(0, least(1, 1 - rarity_global / 100.0)), 3)
          )), 2)
        END)
  ), 'Every PSN Platinum must use the native rarity curve with five times the rarity component';
END;
$$;

COMMIT;
