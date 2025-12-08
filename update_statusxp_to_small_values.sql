-- Update base_status_xp to smaller values for user-friendly scores
-- Old: 10, 13, 18, 23, 30 → New: 0.5, 0.65, 0.9, 1.15, 1.5 (÷20)

-- First, change the column type to allow decimals
ALTER TABLE achievements
ALTER COLUMN base_status_xp TYPE NUMERIC(6,2);

-- Update existing values
UPDATE achievements
SET base_status_xp = CASE
    WHEN include_in_score = false THEN 0
    WHEN rarity_global IS NULL THEN 0.5
    WHEN rarity_global > 25 THEN 0.5
    WHEN rarity_global > 10 THEN 0.65
    WHEN rarity_global > 5 THEN 0.9
    WHEN rarity_global > 1 THEN 1.15
    ELSE 1.5
END
WHERE base_status_xp IS NOT NULL;

-- Update the trigger function
CREATE OR REPLACE FUNCTION trigger_update_achievement_rarity()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.rarity_global IS NOT NULL THEN
    NEW.rarity_band := CASE
        WHEN NEW.rarity_global > 25 THEN 'COMMON'
        WHEN NEW.rarity_global > 10 THEN 'UNCOMMON'
        WHEN NEW.rarity_global > 5 THEN 'RARE'
        WHEN NEW.rarity_global > 1 THEN 'VERY_RARE'
        ELSE 'ULTRA_RARE'
    END;

    NEW.rarity_multiplier := CASE
        WHEN NEW.rarity_global > 25 THEN 1.00
        WHEN NEW.rarity_global > 10 THEN 1.25
        WHEN NEW.rarity_global > 5 THEN 1.75
        WHEN NEW.rarity_global > 1 THEN 2.25
        ELSE 3.00
    END;

    NEW.base_status_xp := CASE
        WHEN NEW.include_in_score = false THEN 0
        WHEN NEW.rarity_global > 25 THEN 0.5
        WHEN NEW.rarity_global > 10 THEN 0.65
        WHEN NEW.rarity_global > 5 THEN 0.9
        WHEN NEW.rarity_global > 1 THEN 1.15
        ELSE 1.5
    END;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Update recalculate function
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
          WHEN rarity_global IS NULL THEN 0.5
          WHEN rarity_global > 25 THEN 0.5
          WHEN rarity_global > 10 THEN 0.65
          WHEN rarity_global > 5 THEN 0.9
          WHEN rarity_global > 1 THEN 1.15
          ELSE 1.5
      END
  WHERE rarity_global IS NOT NULL;
END;
$$ LANGUAGE plpgsql;

-- Note: User scores will be recalculated automatically by triggers on next achievement earn
-- Or you can manually run: SELECT recalculate_achievement_rarity();
