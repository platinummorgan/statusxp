-- STATUSXP SMOKE TEST FOR USER: 84b60ad6-cb2c-484f-8953-bf814551fd7a
-- Detailed breakdown of Xbox and Steam calculations

-- Xbox game with most StatusXP
WITH xbox_top AS (
  SELECT platform_id, platform_game_id, game_name, statusxp_effective
  FROM calculate_statusxp_with_stacks('84b60ad6-cb2c-484f-8953-bf814551fd7a')
  WHERE platform_id = 11
  ORDER BY statusxp_effective DESC
  LIMIT 1
)
SELECT 
  a.platform_achievement_id,
  a.name AS achievement_name,
  a.rarity_global,
  a.base_status_xp,
  a.rarity_multiplier,
  (a.base_status_xp * a.rarity_multiplier) AS contribution,
  a.include_in_score,
  CASE 
    WHEN a.rarity_global IS NULL THEN 'UNKNOWN'
    WHEN a.rarity_global > 25 THEN 'COMMON'
    WHEN a.rarity_global > 10 THEN 'UNCOMMON'
    WHEN a.rarity_global > 5 THEN 'RARE'
    WHEN a.rarity_global > 1 THEN 'VERY_RARE'
    ELSE 'ULTRA_RARE'
  END AS rarity_tier
FROM achievements a
JOIN user_achievements ua ON ua.platform_id = a.platform_id
  AND ua.platform_game_id = a.platform_game_id
  AND ua.platform_achievement_id = a.platform_achievement_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND a.platform_id = (SELECT platform_id FROM xbox_top)
  AND a.platform_game_id = (SELECT platform_game_id FROM xbox_top)
ORDER BY contribution DESC;

-- Xbox game total verification
WITH xbox_top AS (
  SELECT platform_id, platform_game_id, game_name, statusxp_effective
  FROM calculate_statusxp_with_stacks('84b60ad6-cb2c-484f-8953-bf814551fd7a')
  WHERE platform_id = 11
  ORDER BY statusxp_effective DESC
  LIMIT 1
)
SELECT 
  xt.game_name,
  xt.statusxp_effective AS calculated_total,
  SUM(a.base_status_xp * a.rarity_multiplier)::integer AS manual_sum,
  COUNT(*) AS achievement_count
FROM xbox_top xt
JOIN achievements a ON a.platform_id = xt.platform_id AND a.platform_game_id = xt.platform_game_id
JOIN user_achievements ua ON ua.platform_id = a.platform_id
  AND ua.platform_game_id = a.platform_game_id
  AND ua.platform_achievement_id = a.platform_achievement_id
  AND ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
WHERE a.include_in_score = true
GROUP BY xt.game_name, xt.statusxp_effective;

-- Steam game with most StatusXP
WITH steam_top AS (
  SELECT platform_id, platform_game_id, game_name, statusxp_effective
  FROM calculate_statusxp_with_stacks('84b60ad6-cb2c-484f-8953-bf814551fd7a')
  WHERE platform_id = 4
  ORDER BY statusxp_effective DESC
  LIMIT 1
)
SELECT 
  a.platform_achievement_id,
  a.name AS achievement_name,
  a.rarity_global,
  a.base_status_xp,
  a.rarity_multiplier,
  (a.base_status_xp * a.rarity_multiplier) AS contribution,
  a.include_in_score,
  CASE 
    WHEN a.rarity_global IS NULL THEN 'UNKNOWN'
    WHEN a.rarity_global > 25 THEN 'COMMON'
    WHEN a.rarity_global > 10 THEN 'UNCOMMON'
    WHEN a.rarity_global > 5 THEN 'RARE'
    WHEN a.rarity_global > 1 THEN 'VERY_RARE'
    ELSE 'ULTRA_RARE'
  END AS rarity_tier
FROM achievements a
JOIN user_achievements ua ON ua.platform_id = a.platform_id
  AND ua.platform_game_id = a.platform_game_id
  AND ua.platform_achievement_id = a.platform_achievement_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND a.platform_id = (SELECT platform_id FROM steam_top)
  AND a.platform_game_id = (SELECT platform_game_id FROM steam_top)
ORDER BY contribution DESC;

-- Steam game total verification
WITH steam_top AS (
  SELECT platform_id, platform_game_id, game_name, statusxp_effective
  FROM calculate_statusxp_with_stacks('84b60ad6-cb2c-484f-8953-bf814551fd7a')
  WHERE platform_id = 4
  ORDER BY statusxp_effective DESC
  LIMIT 1
)
SELECT 
  st.game_name,
  st.statusxp_effective AS calculated_total,
  SUM(a.base_status_xp * a.rarity_multiplier)::integer AS manual_sum,
  COUNT(*) AS achievement_count
FROM steam_top st
JOIN achievements a ON a.platform_id = st.platform_id AND a.platform_game_id = st.platform_game_id
JOIN user_achievements ua ON ua.platform_id = a.platform_id
  AND ua.platform_game_id = a.platform_game_id
  AND ua.platform_achievement_id = a.platform_achievement_id
  AND ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
WHERE a.include_in_score = true
GROUP BY st.game_name, st.statusxp_effective;

-- All Xbox games breakdown
SELECT 
  g.name AS game_name,
  COUNT(*) AS earned_achievements,
  SUM(a.base_status_xp * a.rarity_multiplier)::integer AS calculated_statusxp,
  AVG(a.rarity_global) AS avg_rarity,
  COUNT(*) FILTER (WHERE a.base_status_xp = 5) AS common_count,
  COUNT(*) FILTER (WHERE a.base_status_xp = 7) AS uncommon_count,
  COUNT(*) FILTER (WHERE a.base_status_xp = 9) AS rare_count,
  COUNT(*) FILTER (WHERE a.base_status_xp = 12) AS very_rare_count,
  COUNT(*) FILTER (WHERE a.base_status_xp = 15) AS ultra_rare_count
FROM achievements a
JOIN user_achievements ua ON ua.platform_id = a.platform_id
  AND ua.platform_game_id = a.platform_game_id
  AND ua.platform_achievement_id = a.platform_achievement_id
JOIN games g ON g.platform_id = a.platform_id AND g.platform_game_id = a.platform_game_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND a.platform_id = 11
  AND a.include_in_score = true
GROUP BY g.name, a.platform_game_id
ORDER BY calculated_statusxp DESC;

-- All Steam games breakdown
SELECT 
  g.name AS game_name,
  COUNT(*) AS earned_achievements,
  SUM(a.base_status_xp * a.rarity_multiplier)::integer AS calculated_statusxp,
  AVG(a.rarity_global) AS avg_rarity,
  COUNT(*) FILTER (WHERE a.base_status_xp = 5) AS common_count,
  COUNT(*) FILTER (WHERE a.base_status_xp = 7) AS uncommon_count,
  COUNT(*) FILTER (WHERE a.base_status_xp = 9) AS rare_count,
  COUNT(*) FILTER (WHERE a.base_status_xp = 12) AS very_rare_count,
  COUNT(*) FILTER (WHERE a.base_status_xp = 15) AS ultra_rare_count
FROM achievements a
JOIN user_achievements ua ON ua.platform_id = a.platform_id
  AND ua.platform_game_id = a.platform_game_id
  AND ua.platform_achievement_id = a.platform_achievement_id
JOIN games g ON g.platform_id = a.platform_id AND g.platform_game_id = a.platform_game_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND a.platform_id = 4
  AND a.include_in_score = true
GROUP BY g.name, a.platform_game_id
ORDER BY calculated_statusxp DESC;

-- Verify totals match
SELECT 
  'Xbox Total' AS description,
  SUM(statusxp_effective) AS from_function,
  (SELECT SUM(a.base_status_xp * a.rarity_multiplier)::integer
   FROM achievements a
   JOIN user_achievements ua ON ua.platform_id = a.platform_id
     AND ua.platform_game_id = a.platform_game_id
     AND ua.platform_achievement_id = a.platform_achievement_id
   WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
     AND a.platform_id = 11
     AND a.include_in_score = true) AS manual_calculation
FROM calculate_statusxp_with_stacks('84b60ad6-cb2c-484f-8953-bf814551fd7a')
WHERE platform_id = 11

UNION ALL

SELECT 
  'Steam Total' AS description,
  SUM(statusxp_effective) AS from_function,
  (SELECT SUM(a.base_status_xp * a.rarity_multiplier)::integer
   FROM achievements a
   JOIN user_achievements ua ON ua.platform_id = a.platform_id
     AND ua.platform_game_id = a.platform_game_id
     AND ua.platform_achievement_id = a.platform_achievement_id
   WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
     AND a.platform_id = 4
     AND a.include_in_score = true) AS manual_calculation
FROM calculate_statusxp_with_stacks('84b60ad6-cb2c-484f-8953-bf814551fd7a')
WHERE platform_id = 4;
