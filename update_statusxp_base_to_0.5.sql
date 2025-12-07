-- Update StatusXP base value to 0.5 for very compact leaderboard numbers
CREATE OR REPLACE FUNCTION get_achievement_statusxp(
  platform_param text,
  trophy_type_param text,
  rarity_percent numeric
)
RETURNS integer AS $$
DECLARE
  base_value numeric := 0.5;  -- Using 0.5 for compact numbers
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
