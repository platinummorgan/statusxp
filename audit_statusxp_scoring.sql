-- STATUSXP AUDIT QUERY FOR USER: 84b60ad6-cb2c-484f-8953-bf814551fd7a
-- Pick a specific game from each platform and verify the rarity-based scoring

-- First: Check what games you have on each platform
SELECT 
  CASE 
    WHEN platform_id IN (1, 2, 5, 9) THEN 'PSN'
    WHEN platform_id IN (10, 11, 12) THEN 'Xbox'
    WHEN platform_id = 4 THEN 'Steam'
    ELSE 'Other'
  END as platform_group,
  platform_id,
  COUNT(*) as game_count,
  SUM(statusxp_effective) as total_statusxp
FROM calculate_statusxp_with_stacks('84b60ad6-cb2c-484f-8953-bf814551fd7a')
GROUP BY platform_id
ORDER BY platform_id;

-- Diagnostic: compare calculated StatusXP vs stored current_score per game
WITH calc AS (
  SELECT platform_id, platform_game_id, statusxp_effective
  FROM calculate_statusxp_with_stacks('84b60ad6-cb2c-484f-8953-bf814551fd7a')
), stored AS (
  SELECT platform_id, platform_game_id, current_score
  FROM user_progress
  WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
)
SELECT 
  COALESCE(c.platform_id, s.platform_id) AS platform_id,
  COALESCE(c.platform_game_id, s.platform_game_id) AS platform_game_id,
  COALESCE(c.statusxp_effective, 0) AS calc_score,
  COALESCE(s.current_score, 0) AS stored_score,
  COALESCE(s.current_score, 0) - COALESCE(c.statusxp_effective, 0) AS delta
FROM calc c
FULL OUTER JOIN stored s
  ON c.platform_id = s.platform_id AND c.platform_game_id = s.platform_game_id
WHERE COALESCE(s.current_score, 0) <> COALESCE(c.statusxp_effective, 0)
ORDER BY ABS(COALESCE(s.current_score, 0) - COALESCE(c.statusxp_effective, 0)) DESC
LIMIT 50;

-- Diagnostic: totals comparison calc vs stored
WITH calc AS (
  SELECT platform_id, SUM(statusxp_effective)::numeric AS calc_total
  FROM calculate_statusxp_with_stacks('84b60ad6-cb2c-484f-8953-bf814551fd7a')
  GROUP BY platform_id
), stored AS (
  SELECT platform_id, SUM(current_score)::numeric AS stored_total
  FROM user_progress
  WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  GROUP BY platform_id
)
SELECT 
  COALESCE(c.platform_id, s.platform_id) AS platform_id,
  COALESCE(c.calc_total, 0) AS calc_total,
  COALESCE(s.stored_total, 0) AS stored_total,
  COALESCE(s.stored_total, 0) - COALESCE(c.calc_total, 0) AS delta
FROM calc c
FULL OUTER JOIN stored s ON c.platform_id = s.platform_id
ORDER BY platform_id;

-- Diagnostic: rarity multiplier distribution for earned achievements
WITH user_ach AS (
  SELECT a.base_status_xp, a.rarity_multiplier, a.include_in_score
  FROM achievements a
  JOIN user_achievements ua ON ua.platform_id = a.platform_id
    AND ua.platform_game_id = a.platform_game_id
    AND ua.platform_achievement_id = a.platform_achievement_id
  WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
)
SELECT rarity_multiplier, COUNT(*)
FROM user_ach
GROUP BY rarity_multiplier
ORDER BY rarity_multiplier;

-- Base StatusXP audit: distribution should be 5/7/9/12/15 only
-- Checks user's earned achievements and reports counts per base_status_xp value
WITH user_ach AS (
  SELECT a.base_status_xp, a.include_in_score, a.metadata
  FROM achievements a
  JOIN user_achievements ua ON ua.platform_id = a.platform_id
    AND ua.platform_game_id = a.platform_game_id
    AND ua.platform_achievement_id = a.platform_achievement_id
  WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
)
SELECT 
  base_status_xp,
  COUNT(*) as count
FROM user_ach
GROUP BY base_status_xp
ORDER BY base_status_xp;

-- Sanity check: any achievements with base_status_xp > 15?
SELECT COUNT(*) AS over_15_count
FROM achievements a
JOIN user_achievements ua ON ua.platform_id = a.platform_id
  AND ua.platform_game_id = a.platform_game_id
  AND ua.platform_achievement_id = a.platform_achievement_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND COALESCE(a.base_status_xp, 0) > 15;

-- Verify platinums excluded from scoring (PSN only)
SELECT 
  COUNT(*) AS psn_platinums_total,
  COUNT(*) FILTER (WHERE include_in_score = false) AS psn_platinums_excluded
FROM achievements a
WHERE a.platform_id IN (1,2,5,9)
  AND COALESCE((a.metadata->>'psn_trophy_type')::text, '') = 'platinum';
    ELSE 'Other'
  END as platform_group,
  platform_id,
  COUNT(*) as game_count,
  SUM(statusxp_effective) as total_statusxp
FROM calculate_statusxp_with_stacks('84b60ad6-cb2c-484f-8953-bf814551fd7a')
GROUP BY platform_id
ORDER BY platform_id;

-- Base StatusXP audit: distribution should be 1..10 only
-- Checks user's earned achievements and reports counts per base_status_xp value
WITH user_ach AS (

  -- Diagnostic: compare calculated StatusXP vs stored current_score per game
  WITH calc AS (
    SELECT platform_id, platform_game_id, statusxp_effective
    FROM calculate_statusxp_with_stacks('84b60ad6-cb2c-484f-8953-bf814551fd7a')
  ), stored AS (
    SELECT platform_id, platform_game_id, current_score
    FROM user_progress
    WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  )
  SELECT 
    COALESCE(c.platform_id, s.platform_id) AS platform_id,
    COALESCE(c.platform_game_id, s.platform_game_id) AS platform_game_id,
    COALESCE(c.statusxp_effective, 0) AS calc_score,
    COALESCE(s.current_score, 0) AS stored_score,
    COALESCE(s.current_score, 0) - COALESCE(c.statusxp_effective, 0) AS delta
  FROM calc c
  FULL OUTER JOIN stored s
    ON c.platform_id = s.platform_id AND c.platform_game_id = s.platform_game_id
  WHERE COALESCE(s.current_score, 0) <> COALESCE(c.statusxp_effective, 0)
  ORDER BY ABS(COALESCE(s.current_score, 0) - COALESCE(c.statusxp_effective, 0)) DESC
  LIMIT 50;

  -- Diagnostic: totals comparison calc vs stored
  WITH calc AS (
    SELECT platform_id, SUM(statusxp_effective)::numeric AS calc_total
    FROM calculate_statusxp_with_stacks('84b60ad6-cb2c-484f-8953-bf814551fd7a')
    GROUP BY platform_id
  ), stored AS (
    SELECT platform_id, SUM(current_score)::numeric AS stored_total
    FROM user_progress
    WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
    GROUP BY platform_id
  )
  SELECT 
    COALESCE(c.platform_id, s.platform_id) AS platform_id,
    COALESCE(c.calc_total, 0) AS calc_total,
    COALESCE(s.stored_total, 0) AS stored_total,
    COALESCE(s.stored_total, 0) - COALESCE(c.calc_total, 0) AS delta
  FROM calc c
  FULL OUTER JOIN stored s ON c.platform_id = s.platform_id
  ORDER BY platform_id;

  -- Diagnostic: rarity multiplier distribution for earned achievements
  WITH user_ach AS (
    SELECT a.base_status_xp, a.rarity_multiplier, a.include_in_score
    FROM achievements a
    JOIN user_achievements ua ON ua.platform_id = a.platform_id
      AND ua.platform_game_id = a.platform_game_id
      AND ua.platform_achievement_id = a.platform_achievement_id
    WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  )
  SELECT rarity_multiplier, COUNT(*)
  FROM user_ach
  GROUP BY rarity_multiplier
  ORDER BY rarity_multiplier;
  SELECT a.base_status_xp, a.include_in_score, a.metadata
  FROM achievements a
  JOIN user_achievements ua ON ua.platform_id = a.platform_id
    AND ua.platform_game_id = a.platform_game_id
    AND ua.platform_achievement_id = a.platform_achievement_id
  WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
)
SELECT 
  base_status_xp,
  COUNT(*) as count
FROM user_ach
GROUP BY base_status_xp
ORDER BY base_status_xp;

-- Sanity check: any achievements with base_status_xp > 10?
SELECT COUNT(*) AS over_10_count
FROM achievements a
JOIN user_achievements ua ON ua.platform_id = a.platform_id
  AND ua.platform_game_id = a.platform_game_id
  AND ua.platform_achievement_id = a.platform_achievement_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND COALESCE(a.base_status_xp, 0) > 10;

-- Verify platinums excluded from scoring (PSN only)
SELECT 
  COUNT(*) AS psn_platinums_total,
  COUNT(*) FILTER (WHERE include_in_score = false) AS psn_platinums_excluded
FROM achievements a
WHERE a.platform_id IN (1,2,5,9)
  AND COALESCE((a.metadata->>'psn_trophy_type')::text, '') = 'platinum';
