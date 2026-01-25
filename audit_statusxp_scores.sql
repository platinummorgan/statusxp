-- Audit StatusXP scores - verify they're calculated correctly

-- 1. Check one user's StatusXP calculation
-- XxlmThumperxX: Should sum base_status_xp * rarity_multiplier for earned achievements
WITH one_user_calc AS (
  SELECT 
    ua.user_id,
    ua.platform_id,
    ua.platform_game_id,
    SUM(a.base_status_xp * a.rarity_multiplier) as calculated_statusxp
  FROM user_achievements ua
  JOIN achievements a ON 
    a.platform_id = ua.platform_id
    AND a.platform_game_id = ua.platform_game_id
    AND a.platform_achievement_id = ua.platform_achievement_id
  WHERE ua.user_id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d'  -- XxlmThumperxX
    AND a.include_in_score = true  -- Exclude platinums
  GROUP BY ua.user_id, ua.platform_id, ua.platform_game_id
)
SELECT 
  ouc.user_id,
  ouc.platform_id,
  ouc.platform_game_id,
  ouc.calculated_statusxp,
  up.current_score as stored_statusxp,
  (ouc.calculated_statusxp - up.current_score) as difference,
  ROUND(ouc.calculated_statusxp)::integer as calculated_rounded
FROM one_user_calc ouc
LEFT JOIN user_progress up ON 
  up.user_id = ouc.user_id 
  AND up.platform_id = ouc.platform_id 
  AND up.platform_game_id = ouc.platform_game_id
ORDER BY ouc.calculated_statusxp DESC
LIMIT 20;

-- 2. Sample of achievements to verify exponential curve is applied
SELECT 
  platform_id,
  platform_game_id,
  name,
  rarity_global,
  base_status_xp,
  rarity_multiplier,
  (base_status_xp * rarity_multiplier) as final_statusxp,
  include_in_score
FROM achievements
WHERE platform_id IN (1, 2, 4, 5, 9, 10, 11, 12)
  AND rarity_global IS NOT NULL
ORDER BY rarity_global DESC
LIMIT 30;

-- 3. Check if rarity_multiplier is actually 1.0 everywhere
SELECT 
  COUNT(*) as total_achievements,
  COUNT(CASE WHEN rarity_multiplier = 1.0 THEN 1 END) as multiplier_1,
  COUNT(CASE WHEN rarity_multiplier != 1.0 THEN 1 END) as multiplier_other,
  MIN(rarity_multiplier) as min_multiplier,
  MAX(rarity_multiplier) as max_multiplier
FROM achievements
WHERE platform_id IN (1, 2, 4, 5, 9, 10, 11, 12);

-- 4. Verify include_in_score is set (platinums excluded)
SELECT 
  COUNT(*) as total_achievements,
  COUNT(CASE WHEN include_in_score = true THEN 1 END) as included,
  COUNT(CASE WHEN include_in_score = false THEN 1 END) as excluded,
  COUNT(CASE WHEN include_in_score IS NULL THEN 1 END) as null_values
FROM achievements
WHERE platform_id IN (1, 2, 4, 5, 9, 10, 11, 12);

-- 5. Check base_status_xp distribution (should be 0.5 to 12.0 with decimals)
SELECT 
  ROUND(base_status_xp, 1) as score_rounded,
  COUNT(*) as count,
  AVG(rarity_global) as avg_rarity,
  MIN(rarity_global) as min_rarity,
  MAX(rarity_global) as max_rarity
FROM achievements
WHERE platform_id IN (1, 2, 4, 5, 9, 10, 11, 12)
  AND include_in_score = true
GROUP BY ROUND(base_status_xp, 1)
ORDER BY base_status_xp DESC;
