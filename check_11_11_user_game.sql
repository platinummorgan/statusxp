-- Check what StatusXP calculation is stored in user_games for 11-11
SELECT
  gt.name as game_name,
  ug.statusxp_raw,
  ug.statusxp_effective,
  ug.stack_multiplier,
  ug.total_trophies,
  ug.earned_trophies,
  p.code as platform
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
JOIN platforms p ON ug.platform_id = p.id
WHERE gt.name ILIKE '%11-11%'
  AND ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Also check how statusxp_raw is calculated
-- It should be the sum of base_status_xp for all earned achievements
SELECT
  SUM(a.base_status_xp::numeric) as sum_of_base_statusxp
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id
JOIN game_titles gt ON a.game_title_id = gt.id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND gt.name ILIKE '%11-11%'
  AND a.platform = 'psn';
