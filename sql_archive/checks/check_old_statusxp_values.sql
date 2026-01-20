-- Check if old StatusXP values exist in user_progress metadata
SELECT 
  user_id,
  platform_id,
  platform_game_id,
  metadata->>'statusxp_raw' as statusxp_raw,
  metadata->>'statusxp_effective' as statusxp_effective,
  metadata->>'stack_multiplier' as stack_multiplier,
  achievements_earned,
  total_achievements,
  completion_percentage
FROM user_progress
WHERE user_id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d'
  AND (
    metadata->>'statusxp_raw' IS NOT NULL 
    OR metadata->>'statusxp_effective' IS NOT NULL
  )
LIMIT 20;

-- Also check what keys exist in metadata
SELECT DISTINCT jsonb_object_keys(metadata) as metadata_key
FROM user_progress
WHERE user_id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d'
  AND metadata != '{}'::jsonb;
