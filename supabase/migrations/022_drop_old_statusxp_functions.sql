-- Migration: Drop old StatusXP calculation system
-- Created: 2025-12-08
-- Description: Remove obsolete functions/views from migration 013 that used 100-300 XP calculation
--              The current system (migration 020) uses base_status_xp column with 10-30 XP values

-- Drop old views that depend on the obsolete functions
DROP VIEW IF EXISTS user_statusxp_summary CASCADE;
DROP VIEW IF EXISTS user_statusxp_totals CASCADE;
DROP VIEW IF EXISTS user_statusxp_scores CASCADE;

-- Drop old calculation functions (from migration 013)
DROP FUNCTION IF EXISTS get_achievement_statusxp(text, text, numeric) CASCADE;
DROP FUNCTION IF EXISTS get_rarity_multiplier(numeric) CASCADE;

-- Add helpful comments to current columns
COMMENT ON COLUMN achievements.base_status_xp IS 'StatusXP value (10-30) auto-calculated by trigger_update_achievement_rarity() from rarity_global. COMMON (>25%) = 10, UNCOMMON (10-25%) = 13, RARE (5-10%) = 18, VERY_RARE (1-5%) = 23, ULTRA_RARE (<=1%) = 30. Set to 0 if include_in_score = false.';

COMMENT ON COLUMN achievements.rarity_multiplier IS 'Multiplier (1.00-3.00) auto-calculated by trigger_update_achievement_rarity() from rarity_global. Used for game-level StatusXP calculations in user_games.statusxp_effective.';

COMMENT ON COLUMN user_games.statusxp_raw IS 'Sum of base_status_xp for all earned achievements in this game (base game only, excludes DLC).';

COMMENT ON COLUMN user_games.statusxp_effective IS 'Final StatusXP for this game: statusxp_raw × stack_multiplier. Used for leaderboards and totals.';
