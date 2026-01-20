-- Check what base_status_xp values are currently in the database
SELECT 
  rarity_band,
  COUNT(*) as achievement_count,
  MIN(base_status_xp) as min_points,
  MAX(base_status_xp) as max_points,
  MODE() WITHIN GROUP (ORDER BY base_status_xp) as most_common_points
FROM achievements
WHERE include_in_score = true
GROUP BY rarity_band
ORDER BY 
  CASE rarity_band
    WHEN 'ULTRA_RARE' THEN 1
    WHEN 'VERY_RARE' THEN 2
    WHEN 'RARE' THEN 3
    WHEN 'UNCOMMON' THEN 4
    WHEN 'COMMON' THEN 5
  END;
