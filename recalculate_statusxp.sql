-- Recalculate StatusXP for all achievements and games
-- Run this to fix existing achievements that have 0 StatusXP

-- First, ensure all achievements have their rarity bands and base_status_xp calculated
SELECT recalculate_achievement_rarity();

-- Calculate raw and effective StatusXP for all user games
SELECT calculate_user_game_statusxp();

-- Verify results - check total StatusXP by platform
SELECT 
  p.name as platform,
  COUNT(DISTINCT ug.game_title_id) as games,
  SUM(ug.earned_trophies) as achievements_earned,
  SUM(ug.statusxp_raw) as total_raw_xp,
  SUM(ug.statusxp_effective) as total_effective_xp
FROM user_games ug
JOIN platforms p ON ug.platform_id = p.id
WHERE ug.user_id = (SELECT id FROM profiles LIMIT 1)
GROUP BY p.name
ORDER BY p.name;

-- Check your total StatusXP
SELECT 
  user_id,
  SUM(statusxp_effective) as total_statusxp
FROM user_games
WHERE user_id = (SELECT id FROM profiles LIMIT 1)
GROUP BY user_id;
