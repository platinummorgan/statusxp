-- Migration: 020_rarity_based_statusxp.sql
-- Created: 2025-12-07
-- Description: Complete rarity-based StatusXP system with DLC stacking

-- Add columns to achievements table
ALTER TABLE public.achievements
  ADD COLUMN IF NOT EXISTS content_set text DEFAULT 'BASE',
  ADD COLUMN IF NOT EXISTS is_platinum boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS include_in_score boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS rarity_band text,
  ADD COLUMN IF NOT EXISTS rarity_multiplier numeric(4,2),
  ADD COLUMN IF NOT EXISTS base_status_xp int;

-- Add columns to user_achievements table
ALTER TABLE public.user_achievements
  ADD COLUMN IF NOT EXISTS statusxp_points int DEFAULT 0;

-- Add columns to user_games table
ALTER TABLE public.user_games
  ADD COLUMN IF NOT EXISTS statusxp_raw int DEFAULT 0,
  ADD COLUMN IF NOT EXISTS statusxp_effective int DEFAULT 0,
  ADD COLUMN IF NOT EXISTS stack_index int DEFAULT 1,
  ADD COLUMN IF NOT EXISTS stack_multiplier numeric(3,2) DEFAULT 1.0,
  ADD COLUMN IF NOT EXISTS base_completed boolean DEFAULT false;

-- Update is_platinum based on psn_trophy_type
UPDATE public.achievements
SET is_platinum = (psn_trophy_type = 'platinum')
WHERE platform = 'psn';

-- Set include_in_score (exclude platinums from scoring)
UPDATE public.achievements
SET include_in_score = NOT is_platinum;

-- Calculate and populate rarity bands
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

-- Function to recalculate achievement rarity bands (call when rarity_global updated)
CREATE OR REPLACE FUNCTION recalculate_achievement_rarity()
RETURNS void AS $$
BEGIN
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
      END
  WHERE rarity_global IS NOT NULL;
END;
$$ LANGUAGE plpgsql;

-- Function to calculate user achievement StatusXP points
CREATE OR REPLACE FUNCTION calculate_user_achievement_statusxp()
RETURNS void AS $$
BEGIN
  UPDATE public.user_achievements ua
  SET statusxp_points = a.base_status_xp
  FROM public.achievements a
  WHERE ua.achievement_id = a.id;
END;
$$ LANGUAGE plpgsql;

-- Function to calculate user game StatusXP (with DLC stacking)
CREATE OR REPLACE FUNCTION calculate_user_game_statusxp()
RETURNS void AS $$
BEGIN
  -- Calculate raw StatusXP (sum of all achievements for this game)
  WITH game_statusxp AS (
    SELECT 
      ug.id as user_game_id,
      COALESCE(SUM(ua.statusxp_points), 0) as raw_xp,
      COUNT(*) FILTER (WHERE a.is_dlc = false AND ua.id IS NOT NULL) as base_unlocked,
      COUNT(*) FILTER (WHERE a.is_dlc = false) as base_total
    FROM public.user_games ug
    LEFT JOIN public.achievements a ON a.game_title_id = ug.game_title_id AND a.platform = (
      SELECT p.name FROM public.platforms p WHERE p.id = ug.platform_id LIMIT 1
    )
    LEFT JOIN public.user_achievements ua ON ua.achievement_id = a.id AND ua.user_id = ug.user_id
    GROUP BY ug.id
  )
  UPDATE public.user_games ug
  SET 
    statusxp_raw = gs.raw_xp,
    base_completed = (gs.base_total > 0 AND gs.base_unlocked = gs.base_total),
    statusxp_effective = gs.raw_xp * stack_multiplier
  FROM game_statusxp gs
  WHERE ug.id = gs.user_game_id;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update achievement rarity when rarity_global changes
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

CREATE TRIGGER update_achievement_rarity_on_insert_or_update
BEFORE INSERT OR UPDATE OF rarity_global ON public.achievements
FOR EACH ROW
EXECUTE FUNCTION trigger_update_achievement_rarity();

-- Updated view for StatusXP summary
CREATE OR REPLACE VIEW user_statusxp_summary_v2 AS
SELECT 
  ug.user_id,
  COUNT(DISTINCT ug.id) as total_games,
  SUM(ug.statusxp_effective) as total_statusxp,
  SUM(ug.statusxp_raw) as total_statusxp_raw,
  COUNT(*) FILTER (WHERE ug.base_completed = true) as completed_base_games,
  COALESCE(SUM(ua.statusxp_points), 0) as achievement_points
FROM public.user_games ug
LEFT JOIN public.user_achievements ua ON ua.user_id = ug.user_id
GROUP BY ug.user_id;

-- Run initial calculations
SELECT recalculate_achievement_rarity();
SELECT calculate_user_achievement_statusxp();
SELECT calculate_user_game_statusxp();

COMMENT ON COLUMN achievements.content_set IS 'Content type: BASE, DLC1, DLC2, etc.';
COMMENT ON COLUMN achievements.is_platinum IS 'True for PlayStation platinum trophies';
COMMENT ON COLUMN achievements.include_in_score IS 'Whether to include in StatusXP calculation (excludes platinums)';
COMMENT ON COLUMN achievements.rarity_band IS 'COMMON, UNCOMMON, RARE, VERY_RARE, ULTRA_RARE';
COMMENT ON COLUMN achievements.rarity_multiplier IS 'Multiplier based on rarity: 1.0, 1.25, 1.75, 2.25, 3.0';
COMMENT ON COLUMN achievements.base_status_xp IS 'Base StatusXP points (10, 13, 18, 23, 30)';
COMMENT ON COLUMN user_achievements.statusxp_points IS 'StatusXP points earned for this achievement';
COMMENT ON COLUMN user_games.statusxp_raw IS 'Raw StatusXP (sum of achievement points)';
COMMENT ON COLUMN user_games.statusxp_effective IS 'Effective StatusXP (raw × stack_multiplier)';
COMMENT ON COLUMN user_games.stack_index IS 'Stack position for multi-platform games (1=first, 2=second, etc.)';
COMMENT ON COLUMN user_games.stack_multiplier IS 'Multiplier for stacks: 1.0 for first, 0.5 for subsequent';
COMMENT ON COLUMN user_games.base_completed IS 'True if all base game achievements unlocked';
