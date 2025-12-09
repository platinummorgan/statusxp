-- Check what base_status_xp actually contains for 11-11 Memories Retold
SELECT
  name,
  rarity_global,
  rarity_band,
  base_status_xp,
  psn_trophy_type
FROM achievements
WHERE game_title_id IN (
  SELECT id FROM game_titles WHERE name ILIKE '%11-11%'
)
ORDER BY rarity_global ASC
LIMIT 10;
