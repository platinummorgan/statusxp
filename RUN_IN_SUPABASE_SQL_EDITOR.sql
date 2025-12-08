-- RUN THIS IN SUPABASE SQL EDITOR
-- Complete rarity-based StatusXP implementation
-- Run this entire script in one execution

-- Step 1: Add columns to achievements table
ALTER TABLE public.achievements
  ADD COLUMN IF NOT EXISTS content_set text DEFAULT 'BASE',
  ADD COLUMN IF NOT EXISTS is_platinum boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS include_in_score boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS rarity_band text,
  ADD COLUMN IF NOT EXISTS rarity_multiplier numeric(4,2),
  ADD COLUMN IF NOT EXISTS base_status_xp int;

-- Step 2: Add columns to user_achievements table
ALTER TABLE public.user_achievements
  ADD COLUMN IF NOT EXISTS statusxp_points int DEFAULT 0;

-- Step 3: Add columns to user_games table
ALTER TABLE public.user_games
  ADD COLUMN IF NOT EXISTS statusxp_raw int DEFAULT 0,
  ADD COLUMN IF NOT EXISTS statusxp_effective int DEFAULT 0,
  ADD COLUMN IF NOT EXISTS stack_index int DEFAULT 1,
  ADD COLUMN IF NOT EXISTS stack_multiplier numeric(3,2) DEFAULT 1.0,
  ADD COLUMN IF NOT EXISTS base_completed boolean DEFAULT false;

-- Step 4: Update is_platinum based on psn_trophy_type
UPDATE public.achievements
SET is_platinum = (psn_trophy_type = 'platinum')
WHERE platform = 'psn';

-- Step 5: Set include_in_score (exclude platinums from scoring)
UPDATE public.achievements
SET include_in_score = NOT is_platinum;

-- Step 6: Calculate and populate rarity bands
UPDATE public.achievements
SET rarity_band = CASE
        WHEN rarity_global IS NULL THEN 'COMMON'
        WHEN rarity_global > 25 THEN 'COMMON'
        WHEN rarity_global > 10 THEN 'UNCOMMON'
        WHEN rarity_global > 5 THEN 'RARE'
        WHEN rarity_global > 1 THEN 'VERY_RARE'
        ELSE 'ULTRA_RARE'
    END,
    rarity_multiplier = CASE
        WHEN rarity_global IS NULL THEN 1.00
        WHEN rarity_global > 25 THEN 1.00
        WHEN rarity_global > 10 THEN 1.25
        WHEN rarity_global > 5 THEN 1.75
        WHEN rarity_global > 1 THEN 2.25
        ELSE 3.00
    END,
    base_status_xp = CASE
        WHEN include_in_score = false THEN 0
        WHEN rarity_global IS NULL THEN 10
        WHEN rarity_global > 25 THEN 10
        WHEN rarity_global > 10 THEN 13
        WHEN rarity_global > 5 THEN 18
        WHEN rarity_global > 1 THEN 23
        ELSE 30
    END;

-- Step 7: Create trigger to auto-update rarity on insert/update
CREATE OR REPLACE FUNCTION trigger_update_achievement_rarity()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.rarity_global IS DISTINCT FROM OLD.rarity_global THEN
    NEW.rarity_band := CASE
            WHEN NEW.rarity_global IS NULL THEN 'COMMON'
            WHEN NEW.rarity_global > 25 THEN 'COMMON'
            WHEN NEW.rarity_global > 10 THEN 'UNCOMMON'
            WHEN NEW.rarity_global > 5 THEN 'RARE'
            WHEN NEW.rarity_global > 1 THEN 'VERY_RARE'
            ELSE 'ULTRA_RARE'
        END;
    NEW.rarity_multiplier := CASE
            WHEN NEW.rarity_global IS NULL THEN 1.00
            WHEN NEW.rarity_global > 25 THEN 1.00
            WHEN NEW.rarity_global > 10 THEN 1.25
            WHEN NEW.rarity_global > 5 THEN 1.75
            WHEN NEW.rarity_global > 1 THEN 2.25
            ELSE 3.00
        END;
    NEW.base_status_xp := CASE
            WHEN NEW.include_in_score = false THEN 0
            WHEN NEW.rarity_global IS NULL THEN 10
            WHEN NEW.rarity_global > 25 THEN 10
            WHEN NEW.rarity_global > 10 THEN 13
            WHEN NEW.rarity_global > 5 THEN 18
            WHEN NEW.rarity_global > 1 THEN 23
            ELSE 30
        END;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_achievement_rarity_on_insert_or_update ON public.achievements;
CREATE TRIGGER update_achievement_rarity_on_insert_or_update
BEFORE INSERT OR UPDATE OF rarity_global ON public.achievements
FOR EACH ROW
EXECUTE FUNCTION trigger_update_achievement_rarity();

-- Done! The trigger will now automatically calculate rarity bands when sync services insert/update achievements
