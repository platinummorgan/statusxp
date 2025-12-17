-- First, check the data type of base_status_xp
SELECT column_name, data_type, numeric_precision, numeric_scale
FROM information_schema.columns
WHERE table_name = 'achievements' 
  AND column_name = 'base_status_xp';

-- Fix the data type if it's wrong (should be integer, not numeric)
ALTER TABLE achievements ALTER COLUMN base_status_xp TYPE integer USING base_status_xp::integer;

-- Now recalculate the base_status_xp with correct values (10, 13, 18, 23, 30)
UPDATE achievements
SET base_status_xp = CASE
    WHEN include_in_score = false THEN 0
    WHEN rarity_global IS NULL THEN 10
    WHEN rarity_global > 25 THEN 10
    WHEN rarity_global > 10 THEN 13
    WHEN rarity_global > 5 THEN 18
    WHEN rarity_global > 1 THEN 23
    ELSE 30
END
WHERE platform = 'steam';

-- Verify the fix
SELECT 
  name,
  rarity_global,
  rarity_band,
  base_status_xp
FROM achievements
WHERE platform = 'steam'
  AND id IN (
    SELECT achievement_id FROM user_achievements 
    WHERE user_id = (SELECT id FROM profiles LIMIT 1)
  )
ORDER BY base_status_xp DESC;
