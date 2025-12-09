-- Drop old StatusXP calculation functions and views that are OBSOLETE
-- These used the old 100-300 XP system and are no longer needed
-- The app now uses base_status_xp column directly (10-30 XP)

-- Drop old views that depend on the functions
DROP VIEW IF EXISTS user_statusxp_summary CASCADE;
DROP VIEW IF EXISTS user_statusxp_totals CASCADE;
DROP VIEW IF EXISTS user_statusxp_scores CASCADE;

-- Drop old calculation functions
DROP FUNCTION IF EXISTS get_achievement_statusxp(text, text, numeric) CASCADE;
DROP FUNCTION IF EXISTS get_rarity_multiplier(numeric) CASCADE;

-- Verify they're gone
SELECT 
  routine_name,
  routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name LIKE '%statusxp%';

SELECT 
  table_name,
  table_type
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name LIKE '%statusxp%';

COMMENT ON COLUMN achievements.base_status_xp IS 'StatusXP value (10-30) calculated by trigger from rarity_global. COMMON=10, UNCOMMON=13, RARE=18, VERY_RARE=23, ULTRA_RARE=30';
