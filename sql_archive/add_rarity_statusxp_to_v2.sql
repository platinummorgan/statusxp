-- ============================================================================
-- ADD RARITY-BASED STATUSXP TO V2 SCHEMA
-- ============================================================================
-- The V2 migration dropped base_status_xp and rarity_multiplier columns
-- Need to restore rarity-based StatusXP calculation system

BEGIN;

-- Add rarity-based StatusXP columns to achievements table
ALTER TABLE achievements
  ADD COLUMN IF NOT EXISTS base_status_xp INTEGER DEFAULT 10,
  ADD COLUMN IF NOT EXISTS rarity_multiplier NUMERIC(4,2) DEFAULT 1.00,
  ADD COLUMN IF NOT EXISTS include_in_score BOOLEAN DEFAULT true;

-- Mark platinum trophies (don't include in score calculations)
UPDATE achievements
SET include_in_score = NOT COALESCE((metadata->>'is_platinum')::boolean, false)
WHERE platform_id = 1;

-- Calculate base_status_xp and rarity_multiplier for all achievements
UPDATE achievements
SET 
  base_status_xp = CASE
    WHEN include_in_score = false THEN 0
    WHEN rarity_global IS NULL THEN 10
    WHEN rarity_global > 25 THEN 10
    WHEN rarity_global > 10 THEN 13
    WHEN rarity_global > 5 THEN 18
    WHEN rarity_global > 1 THEN 23
    ELSE 30
  END,
  rarity_multiplier = CASE
    WHEN rarity_global IS NULL THEN 1.00
    WHEN rarity_global > 25 THEN 1.00
    WHEN rarity_global > 10 THEN 1.25
    WHEN rarity_global > 5 THEN 1.75
    WHEN rarity_global > 1 THEN 2.25
    ELSE 3.00
  END;

-- Create index on rarity columns for performance
CREATE INDEX IF NOT EXISTS idx_achievements_statusxp ON achievements(base_status_xp, rarity_multiplier);

-- Create trigger to auto-calculate rarity bands when rarity_global changes
CREATE OR REPLACE FUNCTION trigger_update_achievement_rarity()
RETURNS TRIGGER AS $$
BEGIN
  NEW.base_status_xp := CASE
    WHEN NEW.include_in_score = false THEN 0
    WHEN NEW.rarity_global IS NULL THEN 10
    WHEN NEW.rarity_global > 25 THEN 10
    WHEN NEW.rarity_global > 10 THEN 13
    WHEN NEW.rarity_global > 5 THEN 18
    WHEN NEW.rarity_global > 1 THEN 23
    ELSE 30
  END;
  
  NEW.rarity_multiplier := CASE
    WHEN NEW.rarity_global IS NULL THEN 1.00
    WHEN NEW.rarity_global > 25 THEN 1.00
    WHEN NEW.rarity_global > 10 THEN 1.25
    WHEN NEW.rarity_global > 5 THEN 1.75
    WHEN NEW.rarity_global > 1 THEN 2.25
    ELSE 3.00
  END;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_achievement_rarity ON achievements;
CREATE TRIGGER trigger_achievement_rarity
  BEFORE INSERT OR UPDATE OF rarity_global ON achievements
  FOR EACH ROW
  EXECUTE FUNCTION trigger_update_achievement_rarity();

COMMIT;

-- Verification
SELECT 
  'Rarity-based StatusXP added to V2' as status,
  COUNT(*) as total_achievements,
  COUNT(*) FILTER (WHERE base_status_xp = 10) as common,
  COUNT(*) FILTER (WHERE base_status_xp = 13) as uncommon,
  COUNT(*) FILTER (WHERE base_status_xp = 18) as rare,
  COUNT(*) FILTER (WHERE base_status_xp = 23) as very_rare,
  COUNT(*) FILTER (WHERE base_status_xp = 30) as ultra_rare
FROM achievements;
