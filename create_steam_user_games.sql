-- Just create the missing user_games records for Steam
-- (keeping your base_status_xp values as they are)

-- Show what base values you're using
SELECT 
  rarity_band,
  MIN(base_status_xp) as min_xp,
  MAX(base_status_xp) as max_xp,
  COUNT(*) as achievement_count
FROM achievements
WHERE platform = 'steam'
GROUP BY rarity_band
ORDER BY min_xp DESC;

-- Create missing user_games records for Steam
INSERT INTO user_games (user_id, game_title_id, platform_id, total_trophies, earned_trophies, completion_percent)
SELECT 
  ua.user_id,
  a.game_title_id,
  p.id as platform_id,
  COUNT(DISTINCT all_achievements.id) as total_trophies,
  COUNT(DISTINCT ua.achievement_id) as earned_trophies,
  (COUNT(DISTINCT ua.achievement_id)::float / NULLIF(COUNT(DISTINCT all_achievements.id), 0) * 100) as completion_percent
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id
JOIN platforms p ON p.code = 'Steam'
LEFT JOIN achievements all_achievements ON all_achievements.game_title_id = a.game_title_id AND all_achievements.platform = 'steam'
WHERE a.platform = 'steam'
  AND ua.user_id = (SELECT id FROM profiles LIMIT 1)
  AND NOT EXISTS (
    SELECT 1 FROM user_games ug 
    WHERE ug.user_id = ua.user_id 
      AND ug.game_title_id = a.game_title_id 
      AND ug.platform_id = p.id
  )
GROUP BY ua.user_id, a.game_title_id, p.id
ON CONFLICT (user_id, game_title_id, platform_id) DO NOTHING;

-- Calculate StatusXP
SELECT calculate_user_game_statusxp();

-- Check Steam games now
SELECT 
  gt.name,
  p.name as platform,
  ug.earned_trophies,
  ug.total_trophies,
  ug.statusxp_raw,
  ug.statusxp_effective,
  ug.completion_percent
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
JOIN platforms p ON ug.platform_id = p.id
WHERE p.code = 'Steam'
  AND ug.user_id = (SELECT id FROM profiles LIMIT 1);

-- Final total StatusXP
SELECT 
  p.name as platform,
  SUM(ug.statusxp_effective) as platform_statusxp
FROM user_games ug
JOIN platforms p ON ug.platform_id = p.id
WHERE ug.user_id = (SELECT id FROM profiles LIMIT 1)
GROUP BY p.name
ORDER BY p.name;

SELECT SUM(statusxp_effective) as total_statusxp
FROM user_games
WHERE user_id = (SELECT id FROM profiles LIMIT 1);
