-- Migration: Align StatusXP scoring to rarity bands and multipliers; remove stacking; scale base values
-- Date: 2026-01-24
-- Summary:
-- 1) Scale base_status_xp values by 0.5 to reduce totals (10→5, 13→7, 18→9, 23→12, 30→15)
-- 2) Normalize rarity_multiplier to 1.00,1.25,1.75,2.25,3.00 by rarity bands
-- 3) Update calculate_achievement_statusxp() to set banded base values (no logarithmic formula)
-- 4) Update calculate_statusxp_with_stacks() to sum base_status_xp * rarity_multiplier and remove stack penalties

BEGIN;

-- Step 1: Scale existing base_status_xp by 0.5 for all included achievements
UPDATE public.achievements
SET base_status_xp = ROUND(COALESCE(base_status_xp, 0) * 0.5)
WHERE include_in_score = true;

-- Step 2: Normalize rarity_multiplier per band
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

-- Step 3: Replace calculate_achievement_statusxp() with banded base values (scaled)
CREATE OR REPLACE FUNCTION public.calculate_achievement_statusxp()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  -- Only calculate if we include in score
  IF NEW.include_in_score = false THEN
    NEW.base_status_xp := 0;
    RETURN NEW;
  END IF;

  -- Default for unknown rarity
  IF NEW.rarity_global IS NULL THEN
    NEW.base_status_xp := 5; -- COMMON default
    RETURN NEW;
  END IF;

  -- Banded values: 5,7,9,12,15 (scaled 0.5x from 10/13/18/23/30)
  IF NEW.rarity_global > 25 THEN
    NEW.base_status_xp := 5;  -- COMMON
  ELSIF NEW.rarity_global > 10 THEN
    NEW.base_status_xp := 7;  -- UNCOMMON
  ELSIF NEW.rarity_global > 5 THEN
    NEW.base_status_xp := 9;  -- RARE
  ELSIF NEW.rarity_global > 1 THEN
    NEW.base_status_xp := 12; -- VERY_RARE
  ELSE
    NEW.base_status_xp := 15; -- ULTRA_RARE
  END IF;

  RETURN NEW;
END;
$$;

-- Step 4: Update calculate_statusxp_with_stacks to use base * rarity_multiplier and no stack penalties
CREATE OR REPLACE FUNCTION public.calculate_statusxp_with_stacks(p_user_id uuid)
RETURNS TABLE(
  platform_id bigint,
  platform_game_id text,
  game_name text,
  achievements_earned integer,
  statusxp_raw integer,
  stack_index integer,
  stack_multiplier numeric,
  statusxp_effective integer
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH game_raw_xp AS (
    SELECT 
      ua.platform_id,
      ua.platform_game_id,
      g.name as game_name,
      COUNT(*)::integer as achievements_earned,
      -- Apply rarity multiplier per achievement
      SUM((a.base_status_xp) * COALESCE(a.rarity_multiplier, 1.0))::integer as statusxp_raw
    FROM public.user_achievements ua
    JOIN public.achievements a ON 
      a.platform_id = ua.platform_id
      AND a.platform_game_id = ua.platform_game_id
      AND a.platform_achievement_id = ua.platform_achievement_id
    JOIN public.games g ON 
      g.platform_id = ua.platform_id
      AND g.platform_game_id = ua.platform_game_id
    WHERE ua.user_id = p_user_id
      AND a.include_in_score = true
    GROUP BY ua.platform_id, ua.platform_game_id, g.name
  ),
  game_stacks AS (
    -- Keep stack_index for reference only; no longer applies penalties
    SELECT 
      grx.*,
      ROW_NUMBER() OVER (
        PARTITION BY grx.platform_id::text || '_' || grx.platform_game_id
        ORDER BY grx.platform_id, grx.platform_game_id
      )::integer as stack_index
    FROM game_raw_xp grx
  )
  SELECT 
    gs.platform_id,
    gs.platform_game_id,
    gs.game_name,
    gs.achievements_earned,
    gs.statusxp_raw,
    gs.stack_index,
    1.0::numeric as stack_multiplier,
    gs.statusxp_raw as statusxp_effective
  FROM game_stacks gs
  ORDER BY statusxp_effective DESC;
END;
$$;

COMMIT;
