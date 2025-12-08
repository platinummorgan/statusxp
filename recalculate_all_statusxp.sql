-- Force recalculation of all StatusXP scores after base value update

-- Step 1: Recalculate base_status_xp for all achievements
SELECT recalculate_achievement_rarity();

-- Step 2: Update user_achievements statusxp_points
UPDATE user_achievements ua
SET statusxp_points = a.base_status_xp
FROM achievements a
WHERE ua.achievement_id = a.id;

-- Step 3: Recalculate user_games totals (with DLC stacking)
WITH game_statusxp AS (
  SELECT 
    ug.id as user_game_id,
    COALESCE(SUM(ua.statusxp_points), 0) as raw_xp,
    COUNT(*) FILTER (WHERE a.is_dlc = false AND ua.id IS NOT NULL) as base_unlocked,
    COUNT(*) FILTER (WHERE a.is_dlc = false) as base_total
  FROM user_games ug
  LEFT JOIN achievements a ON a.game_title_id = ug.game_title_id 
    AND a.platform = (SELECT p.name FROM platforms p WHERE p.id = ug.platform_id LIMIT 1)
  LEFT JOIN user_achievements ua ON ua.achievement_id = a.id AND ua.user_id = ug.user_id
  GROUP BY ug.id
)
UPDATE user_games ug
SET 
  statusxp_raw = gs.raw_xp,
  base_completed = (gs.base_total > 0 AND gs.base_unlocked = gs.base_total),
  statusxp_effective = gs.raw_xp * ug.stack_multiplier
FROM game_statusxp gs
WHERE ug.id = gs.user_game_id;

-- Verify new total (query directly from user_games)
SELECT 
  SUM(statusxp_effective) as total_statusxp,
  COUNT(*) as total_games
FROM user_games
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';
