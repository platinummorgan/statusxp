-- FIX: Include Xbox gamerscore in StatusXP calculation
CREATE OR REPLACE FUNCTION trigger_calculate_statusxp()
RETURNS TRIGGER AS $$
BEGIN
  -- Calculate StatusXP: PSN trophies + Xbox Gamerscore/10
  NEW.statusxp_effective := 
    (COALESCE(NEW.bronze_trophies, 0) * 15) +
    (COALESCE(NEW.silver_trophies, 0) * 30) +
    (COALESCE(NEW.gold_trophies, 0) * 90) +
    (COALESCE(NEW.platinum_trophies, 0) * 300) +
    (COALESCE(NEW.xbox_current_gamerscore, 0) / 10);  -- FIXED!
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate the trigger
DROP TRIGGER IF EXISTS calculate_statusxp_on_upsert ON user_games;
CREATE TRIGGER calculate_statusxp_on_upsert
  BEFORE INSERT OR UPDATE ON user_games
  FOR EACH ROW
  EXECUTE FUNCTION trigger_calculate_statusxp();

-- URGENT: Recalculate ALL games with correct formula including Xbox
UPDATE user_games
SET statusxp_effective = 
  (COALESCE(bronze_trophies, 0) * 15) +
  (COALESCE(silver_trophies, 0) * 30) +
  (COALESCE(gold_trophies, 0) * 90) +
  (COALESCE(platinum_trophies, 0) * 300) +
  (COALESCE(xbox_current_gamerscore, 0) / 10);  -- FIXED!

-- Verify Dex-Morgan's total
SELECT 
  SUM(statusxp_effective) as total_statusxp,
  COUNT(*) as total_games
FROM user_games
WHERE user_id = (SELECT id FROM profiles WHERE username = 'Dex-Morgan');
