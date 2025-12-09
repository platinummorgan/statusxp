-- Fix Xbox achievement totals that are incorrect
-- Update total_trophies to match xbox_total_achievements where they differ
-- (xbox_total_achievements should be the correct value from title history)

-- First, check which games have mismatched values
SELECT 
  gt.name,
  p.code,
  ug.earned_trophies,
  ug.total_trophies AS old_total,
  ug.xbox_total_achievements AS correct_total,
  CASE 
    WHEN ug.total_trophies > 0 THEN 
      ROUND((ug.earned_trophies::decimal / ug.total_trophies::decimal * 100), 1)
    ELSE 0
  END AS old_percent,
  CASE 
    WHEN ug.xbox_total_achievements > 0 THEN 
      ROUND((ug.earned_trophies::decimal / ug.xbox_total_achievements::decimal * 100), 1)
    ELSE 0
  END AS corrected_percent
FROM user_games ug
JOIN game_titles gt ON gt.id = ug.game_title_id
JOIN platforms p ON p.id = ug.platform_id
WHERE p.code ILIKE '%xbox%'
  AND ug.total_trophies != ug.xbox_total_achievements
  AND ug.xbox_total_achievements > 0
ORDER BY gt.name;

-- Uncomment to apply the fix:
-- UPDATE user_games ug
-- SET total_trophies = xbox_total_achievements
-- FROM platforms p
-- WHERE ug.platform_id = p.id
--   AND p.code ILIKE '%xbox%'
--   AND ug.xbox_total_achievements > 0
--   AND ug.total_trophies != ug.xbox_total_achievements;
