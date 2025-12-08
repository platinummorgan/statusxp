-- Check if rarity columns exist in achievements table
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'achievements'
  AND column_name IN ('rarity_global', 'rarity_band', 'rarity_multiplier', 'base_status_xp', 'is_platinum', 'include_in_score', 'content_set')
ORDER BY column_name;

-- Check if new columns exist in user_achievements
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'user_achievements'
  AND column_name = 'statusxp_points';

-- Check if new columns exist in user_games
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'user_games'
  AND column_name IN ('statusxp_raw', 'statusxp_effective', 'stack_index', 'stack_multiplier', 'base_completed')
ORDER BY column_name;

-- Check if we have any rarity_global data populated
SELECT 
  platform,
  COUNT(*) as total_achievements,
  COUNT(rarity_global) as with_rarity,
  ROUND(AVG(rarity_global), 2) as avg_rarity,
  MIN(rarity_global) as rarest,
  MAX(rarity_global) as most_common
FROM achievements
GROUP BY platform;

-- Check if rarity bands are being calculated
SELECT 
  rarity_band,
  rarity_multiplier,
  base_status_xp,
  COUNT(*) as count
FROM achievements
WHERE rarity_global IS NOT NULL
GROUP BY rarity_band, rarity_multiplier, base_status_xp
ORDER BY rarity_multiplier DESC;

-- Sample of achievements with rarity data
SELECT 
  name,
  platform,
  rarity_global,
  rarity_band,
  base_status_xp,
  is_platinum,
  include_in_score
FROM achievements
WHERE rarity_global IS NOT NULL
ORDER BY rarity_global ASC
LIMIT 10;
