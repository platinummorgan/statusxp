-- Fixed recalculation query - platform join was broken
WITH game_statusxp AS (
  SELECT 
    ug.id as user_game_id,
    ug.user_id,
    ug.game_title_id,
    ug.platform_id,
    COALESCE(SUM(ua.statusxp_points), 0) as raw_xp,
    COUNT(*) FILTER (WHERE a.is_dlc = false AND ua.id IS NOT NULL) as base_unlocked,
    COUNT(*) FILTER (WHERE a.is_dlc = false) as base_total
  FROM user_games ug
  LEFT JOIN achievements a ON a.game_title_id = ug.game_title_id 
    AND a.platform IN ('psn', 'xbox', 'steam') -- Fix: platform is stored as lowercase in achievements
  LEFT JOIN user_achievements ua ON ua.achievement_id = a.id AND ua.user_id = ug.user_id
  GROUP BY ug.id, ug.user_id, ug.game_title_id, ug.platform_id
)
UPDATE user_games ug
SET 
  statusxp_raw = gs.raw_xp,
  base_completed = (gs.base_total > 0 AND gs.base_unlocked = gs.base_total),
  statusxp_effective = gs.raw_xp * ug.stack_multiplier
FROM game_statusxp gs
WHERE ug.id = gs.user_game_id;

-- Verify
SELECT 
  SUM(statusxp_effective) as total_statusxp,
  SUM(statusxp_raw) as total_raw,
  COUNT(*) as total_games
FROM user_games
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';
