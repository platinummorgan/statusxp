-- Export full data set for Otaku EVO IX for manual calculation
-- Username: fdymf45xbw

-- 1) Profile
SELECT *
FROM profiles
WHERE username = 'fdymf45xbw';

-- 2) All achievements (earned) with full metadata and scoring fields
SELECT 
  ua.user_id,
  ua.platform_id,
  ua.platform_game_id,
  ua.platform_achievement_id,
  ua.earned_at,
  a.name as achievement_name,
  a.description,
  a.rarity_global,
  a.base_status_xp,
  a.rarity_multiplier,
  (a.base_status_xp * a.rarity_multiplier) as rarity_score,
  a.include_in_score,
  a.score_value,
  a.metadata as achievement_metadata,
  a.metadata->>'platform_version' as api_platform_version,
  a.metadata->>'psn_trophy_type' as api_psn_trophy_type,
  a.metadata->>'trophy_group_id' as api_trophy_group_id,
  a.metadata->>'xbox_is_secret' as api_xbox_is_secret,
  a.metadata->>'steam_hidden' as api_steam_hidden,
  g.name as game_name,
  g.platform_id as game_platform_id
FROM user_achievements ua
JOIN achievements a ON 
  a.platform_id = ua.platform_id
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
JOIN games g ON g.platform_id = ua.platform_id AND g.platform_game_id = ua.platform_game_id
WHERE ua.user_id = (SELECT id FROM profiles WHERE username = 'fdymf45xbw')
ORDER BY ua.platform_id, g.name, ua.earned_at;

-- 3) All games (user_progress)
SELECT 
  up.user_id,
  up.platform_id,
  up.platform_game_id,
  up.current_score,
  up.achievements_earned,
  up.total_achievements,
  up.completion_percentage,
  up.first_played_at,
  up.last_played_at,
  up.last_achievement_earned_at,
  up.metadata,
  g.name as game_name
FROM user_progress up
LEFT JOIN games g ON g.platform_id = up.platform_id AND g.platform_game_id = up.platform_game_id
WHERE up.user_id = (SELECT id FROM profiles WHERE username = 'fdymf45xbw')
ORDER BY up.platform_id, g.name;

-- 4) Per-game StatusXP from calculate_statusxp_with_stacks
SELECT 
  c.platform_id,
  c.platform_game_id,
  c.game_name,
  c.achievements_earned,
  c.statusxp_raw,
  c.statusxp_effective,
  c.stack_multiplier
FROM calculate_statusxp_with_stacks((SELECT id FROM profiles WHERE username = 'fdymf45xbw')) c
ORDER BY c.platform_id, c.game_name;

-- 5) Cached leaderboard totals
SELECT *
FROM leaderboard_cache
WHERE user_id = (SELECT id FROM profiles WHERE username = 'fdymf45xbw');
