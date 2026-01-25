-- StatusXP math breakdown for specific users

-- Replace usernames as needed
WITH target_users AS (
  SELECT id, username, display_name
  FROM profiles
  WHERE username IN ('Dex-Morgan')
)
-- 1) Per-platform StatusXP totals from calculate_statusxp_with_stacks
SELECT 
  tu.username,
  tu.display_name,
  c.platform_id,
  SUM(c.statusxp_effective)::bigint as platform_statusxp,
  COUNT(*) as games_count
FROM target_users tu
JOIN LATERAL calculate_statusxp_with_stacks(tu.id) c ON true
GROUP BY tu.username, tu.display_name, c.platform_id
ORDER BY tu.username, c.platform_id;

-- 2) Raw achievement contribution totals by platform
SELECT 
  tu.username,
  tu.display_name,
  ua.platform_id,
  COUNT(*) as achievements_count,
  SUM(CASE WHEN a.include_in_score = true THEN 1 ELSE 0 END) as included_count,
  SUM(CASE WHEN a.include_in_score = false THEN 1 ELSE 0 END) as excluded_count,
  COALESCE(SUM(a.base_status_xp * a.rarity_multiplier),0)::numeric(12,2) as raw_statusxp
FROM target_users tu
JOIN user_achievements ua ON ua.user_id = tu.id
JOIN achievements a ON 
  a.platform_id = ua.platform_id
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
GROUP BY tu.username, tu.display_name, ua.platform_id
ORDER BY tu.username, ua.platform_id;

-- 3) Missing rarity or excluded achievements by platform
SELECT 
  tu.username,
  tu.display_name,
  ua.platform_id,
  COUNT(*) FILTER (WHERE a.rarity_global IS NULL) as rarity_null_count,
  COUNT(*) FILTER (WHERE a.include_in_score = false) as excluded_count
FROM target_users tu
JOIN user_achievements ua ON ua.user_id = tu.id
JOIN achievements a ON 
  a.platform_id = ua.platform_id
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
GROUP BY tu.username, tu.display_name, ua.platform_id
ORDER BY tu.username, ua.platform_id;

-- 4) Games with achievements but zero StatusXP (should be rare)
SELECT 
  tu.username,
  tu.display_name,
  c.platform_id,
  c.platform_game_id,
  c.game_name,
  c.achievements_earned,
  c.statusxp_raw,
  c.statusxp_effective
FROM target_users tu
JOIN LATERAL calculate_statusxp_with_stacks(tu.id) c ON true
WHERE c.statusxp_effective = 0
ORDER BY tu.username, c.platform_id, c.game_name
LIMIT 200;
