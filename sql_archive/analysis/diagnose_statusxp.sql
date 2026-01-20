-- Diagnostic: Check StatusXP calculation for user with most achievements
-- Returns comprehensive breakdown to identify why StatusXP is 226,633 instead of ~15k

WITH target_user AS (
  SELECT user_id, COUNT(*) as achievement_count
  FROM user_achievements
  GROUP BY user_id
  ORDER BY COUNT(*) DESC
  LIMIT 1
),
user_data AS (
  SELECT 
    ua.user_id,
    ua.platform_id,
    ua.platform_game_id,
    ua.platform_achievement_id,
    a.base_status_xp,
    a.include_in_score,
    a.rarity_multiplier,
    a.rarity_global
  FROM user_achievements ua
  JOIN achievements a ON 
    a.platform_id = ua.platform_id
    AND a.platform_game_id = ua.platform_game_id
    AND a.platform_achievement_id = ua.platform_achievement_id
  WHERE ua.user_id = (SELECT user_id FROM target_user)
)

-- Combined diagnostic results
SELECT 
  'User ID' as metric,
  user_id::text as value,
  NULL::bigint as count,
  NULL::bigint as sum_xp
FROM target_user

UNION ALL

SELECT 
  'Total Achievements',
  NULL,
  COUNT(*)::bigint,
  SUM(base_status_xp)::bigint
FROM user_data

UNION ALL

SELECT 
  'Achievements Included in Score',
  NULL,
  COUNT(*)::bigint,
  SUM(base_status_xp)::bigint
FROM user_data
WHERE include_in_score = true

UNION ALL

SELECT 
  'Achievements Excluded (Platinums)',
  NULL,
  COUNT(*)::bigint,
  SUM(base_status_xp)::bigint
FROM user_data
WHERE include_in_score = false

UNION ALL

SELECT 
  'Common (10 XP)',
  NULL,
  COUNT(*)::bigint,
  SUM(base_status_xp)::bigint
FROM user_data
WHERE base_status_xp = 10

UNION ALL

SELECT 
  'Uncommon (13 XP)',
  NULL,
  COUNT(*)::bigint,
  SUM(base_status_xp)::bigint
FROM user_data
WHERE base_status_xp = 13

UNION ALL

SELECT 
  'Rare (18 XP)',
  NULL,
  COUNT(*)::bigint,
  SUM(base_status_xp)::bigint
FROM user_data
WHERE base_status_xp = 18

UNION ALL

SELECT 
  'Very Rare (23 XP)',
  NULL,
  COUNT(*)::bigint,
  SUM(base_status_xp)::bigint
FROM user_data
WHERE base_status_xp = 23

UNION ALL

SELECT 
  'Ultra Rare (30 XP)',
  NULL,
  COUNT(*)::bigint,
  SUM(base_status_xp)::bigint
FROM user_data
WHERE base_status_xp = 30

ORDER BY 1;
