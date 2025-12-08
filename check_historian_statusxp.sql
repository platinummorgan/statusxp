-- Check the Historian achievement StatusXP data
SELECT
  name,
  platform,
  rarity_global,
  rarity_band,
  rarity_multiplier,
  base_status_xp,
  is_platinum,
  include_in_score,
  psn_trophy_type
FROM achievements
WHERE name ILIKE '%historian%'
LIMIT 5;

-- Also check what's in user_games for statusxp totals
SELECT
  gt.name as game_name,
  ug.platform_id,
  p.code as platform_code,
  ug.statusxp_raw,
  ug.statusxp_effective,
  ug.total_trophies,
  ug.earned_trophies
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
JOIN platforms p ON ug.platform_id = p.id
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND gt.name ILIKE '%cloudpunk%'
ORDER BY ug.statusxp_effective DESC
LIMIT 5;
