-- Update StatusXP base value from 100 to 10
CREATE OR REPLACE FUNCTION get_achievement_statusxp(
  platform_param text,
  trophy_type_param text,
  rarity_percent numeric
)
RETURNS integer AS $$
DECLARE
  base_value integer := 10;  -- Changed from 100 to 10
  multiplier numeric;
BEGIN
  -- Exclude PlayStation Platinums from scoring
  IF platform_param = 'psn' AND trophy_type_param = 'platinum' THEN
    RETURN 0;
  END IF;
  
  -- Get rarity multiplier
  multiplier := get_rarity_multiplier(rarity_percent);
  
  -- Calculate StatusXP
  RETURN (base_value * multiplier)::integer;
END;
$$ LANGUAGE plpgsql IMMUTABLE;
