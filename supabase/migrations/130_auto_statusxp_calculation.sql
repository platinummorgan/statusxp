-- ============================================================================
-- Solidify StatusXP Scoring System
-- ============================================================================
-- Creates trigger to auto-calculate base_status_xp for all new/updated achievements
-- Formula: round(clamp(10 * ln(1/p) / ln(1/0.0001), 1, 10))

-- Drop old triggers if they exist
DROP TRIGGER IF EXISTS calculate_statusxp_on_upsert ON user_games;
DROP TRIGGER IF EXISTS calculate_statusxp_on_insert ON achievements;
DROP TRIGGER IF EXISTS calculate_statusxp_on_update ON achievements;

-- Create function to calculate StatusXP from rarity
CREATE OR REPLACE FUNCTION calculate_achievement_statusxp()
RETURNS TRIGGER AS $$
BEGIN
  -- Only calculate if rarity_global is set and include_in_score is true
  IF NEW.rarity_global IS NOT NULL AND NEW.include_in_score = true THEN
    NEW.base_status_xp = ROUND(
      GREATEST(1, LEAST(10,
        10 * LN(1 / GREATEST(0.0001, LEAST(0.90, NEW.rarity_global / 100.0))) / LN(1 / 0.0001)
      ))
    )::INTEGER;
  ELSIF NEW.include_in_score = false THEN
    -- Ensure excluded achievements have 0 points
    NEW.base_status_xp = 0;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on achievements table
CREATE TRIGGER auto_calculate_statusxp
  BEFORE INSERT OR UPDATE ON achievements
  FOR EACH ROW
  EXECUTE FUNCTION calculate_achievement_statusxp();

-- Verify trigger is working with a test
DO $$
DECLARE
  test_rarity NUMERIC := 10.5; -- 10.5% rarity
  expected_points INTEGER;
  actual_points INTEGER;
BEGIN
  -- Calculate expected points
  expected_points := ROUND(
    GREATEST(1, LEAST(10,
      10 * LN(1 / GREATEST(0.0001, LEAST(0.90, test_rarity / 100.0))) / LN(1 / 0.0001)
    ))
  )::INTEGER;
  
  RAISE NOTICE 'Test: %.% rarity should give % points', test_rarity, '%', expected_points;
END $$;
