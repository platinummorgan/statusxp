-- Check if rarity_multiplier is actually stored in the achievements table
SELECT 
  DISTINCT rarity_multiplier,
  COUNT(*) as count
FROM achievements
WHERE platform_id = 1
GROUP BY rarity_multiplier
ORDER BY rarity_multiplier;

-- Also check a sample of metadata to see what's actually in there
SELECT 
  platform_achievement_id,
  base_status_xp,
  rarity_multiplier,
  metadata
FROM achievements
WHERE platform_id = 1
LIMIT 10;
