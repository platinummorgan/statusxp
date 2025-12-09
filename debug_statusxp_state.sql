-- Debug: Check what's actually in the database now

-- Check achievements table for 11-11
SELECT
  name,
  rarity_global,
  base_status_xp,
  psn_trophy_type
FROM achievements
WHERE game_title_id IN (SELECT id FROM game_titles WHERE name ILIKE '%11-11%')
ORDER BY rarity_global ASC
LIMIT 5;

-- Check user_games table for 11-11
SELECT
  gt.name,
  ug.statusxp_raw,
  ug.statusxp_effective,
  ug.stack_multiplier
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
WHERE gt.name ILIKE '%11-11%'
  AND ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Manually calculate what the sum SHOULD be
SELECT
  SUM(a.base_status_xp::numeric) as manual_sum
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id
JOIN game_titles gt ON a.game_title_id = gt.id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND gt.name ILIKE '%11-11%'
  AND a.platform = 'psn';

-- Check your total StatusXP
SELECT
  SUM(statusxp_effective) as total_statusxp
FROM user_games
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';
