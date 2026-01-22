-- Function to calculate statusxp_effective for a user_game
CREATE OR REPLACE FUNCTION calculate_statusxp_effective(p_user_game_id BIGINT)
RETURNS NUMERIC AS $$
DECLARE
  v_statusxp NUMERIC := 0;
  v_bronze INT;
  v_silver INT;
  v_gold INT;
  v_platinum INT;
BEGIN
  -- Get trophy counts from the user_game
  SELECT 
    bronze_trophies,
    silver_trophies,
    gold_trophies,
    platinum_trophies
  INTO v_bronze, v_silver, v_gold, v_platinum
  FROM user_games
  WHERE id = p_user_game_id;
  
  -- Calculate StatusXP: Bronze=15, Silver=30, Gold=90, Platinum=300
  v_statusxp := 
    (COALESCE(v_bronze, 0) * 15) +
    (COALESCE(v_silver, 0) * 30) +
    (COALESCE(v_gold, 0) * 90) +
    (COALESCE(v_platinum, 0) * 300);
  
  RETURN v_statusxp;
END;
$$ LANGUAGE plpgsql;

-- Trigger function to auto-calculate on insert/update
CREATE OR REPLACE FUNCTION trigger_calculate_statusxp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.statusxp_effective := 
    (COALESCE(NEW.bronze_trophies, 0) * 15) +
    (COALESCE(NEW.silver_trophies, 0) * 30) +
    (COALESCE(NEW.gold_trophies, 0) * 90) +
    (COALESCE(NEW.platinum_trophies, 0) * 300);
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger
DROP TRIGGER IF EXISTS calculate_statusxp_on_upsert ON user_games;
CREATE TRIGGER calculate_statusxp_on_upsert
  BEFORE INSERT OR UPDATE ON user_games
  FOR EACH ROW
  EXECUTE FUNCTION trigger_calculate_statusxp();

-- Backfill all existing games with correct statusxp_effective
UPDATE user_games
SET statusxp_effective = 
  (COALESCE(bronze_trophies, 0) * 15) +
  (COALESCE(silver_trophies, 0) * 30) +
  (COALESCE(gold_trophies, 0) * 90) +
  (COALESCE(platinum_trophies, 0) * 300)
WHERE statusxp_effective IS NULL OR statusxp_effective = 0;

-- Verify the fix for gordonops
SELECT 
  COUNT(*) as total_games,
  COUNT(CASE WHEN statusxp_effective IS NULL OR statusxp_effective = 0 THEN 1 END) as zero_statusxp_games,
  SUM(statusxp_effective) as total_statusxp
FROM user_games
WHERE user_id = (SELECT id FROM profiles WHERE username = 'gordonops');
