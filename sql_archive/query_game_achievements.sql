-- All user achievements with scoring breakdown
SELECT 
  ua.user_id,
  ua.platform_id,
  ua.platform_game_id,
  ua.platform_achievement_id,
  g.name AS game_name,
  a.name AS achievement_name,
  a.rarity_global,
  a.base_status_xp,
  a.rarity_multiplier,
  (a.base_status_xp * a.rarity_multiplier) AS contribution,
  a.include_in_score,
  ua.earned_at
FROM user_achievements ua
JOIN achievements a ON a.platform_id = ua.platform_id
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
JOIN games g ON g.platform_id = ua.platform_id AND g.platform_game_id = ua.platform_game_id
ORDER BY ua.user_id, ua.platform_id, ua.platform_game_id, ua.earned_at;
