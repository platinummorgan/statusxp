-- Check what base_status_xp actually contains
SELECT
  name,
  platform,
  rarity_global,
  rarity_multiplier,
  base_status_xp,
  psn_trophy_type,
  game_title_id
FROM achievements
WHERE rarity_global IS NOT NULL
ORDER BY base_status_xp DESC NULLS LAST
LIMIT 20;

-- Check if base_status_xp is being populated at all
SELECT
  COUNT(*) as total_achievements,
  COUNT(base_status_xp) as has_statusxp,
  COUNT(rarity_global) as has_rarity,
  MIN(base_status_xp) as min_xp,
  MAX(base_status_xp) as max_xp,
  AVG(base_status_xp) as avg_xp
FROM achievements;
