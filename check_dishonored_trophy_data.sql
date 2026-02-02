-- Check Dishonored trophy data in user_games view
SELECT 
  ug.game_title,
  ug.game_title_id,
  ug.platform_id,
  ug.earned_trophies,
  ug.total_trophies,
  ug.bronze_trophies,
  ug.silver_trophies,
  ug.gold_trophies,
  ug.platinum_trophies,
  ug.completion_percent
FROM user_games ug
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND ug.game_title ILIKE '%dishonored%'
ORDER BY ug.game_title;

-- Check if join condition matches for Dishonored
SELECT 
  'user_games' as source,
  ug.game_title,
  ug.game_title_id,
  ug.platform_id,
  NULL as platform_game_id,
  ug.bronze_trophies,
  ug.silver_trophies,
  ug.gold_trophies,
  ug.platinum_trophies
FROM user_games ug
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND ug.game_title ILIKE '%dishonored%'

UNION ALL

SELECT 
  'user_progress hash' as source,
  g.name as game_title,
  (('x'::text || substr(md5((up.platform_id::text || '_'::text) || up.platform_game_id), 1, 15)))::bit(60)::bigint as game_title_id,
  up.platform_id,
  up.platform_game_id,
  NULL as bronze_trophies,
  NULL as silver_trophies,
  NULL as gold_trophies,
  NULL as platinum_trophies
FROM user_progress up
JOIN games g ON g.platform_id = up.platform_id AND g.platform_game_id = up.platform_game_id
WHERE up.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND g.name ILIKE '%dishonored%'
ORDER BY source, game_title;

-- Check raw user_achievements data for Dishonored
SELECT 
  ua.platform_id,
  ua.platform_game_id,
  g.name as game_name,
  COUNT(*) as achievements_earned,
  COUNT(*) FILTER (WHERE a.metadata->>'psn_trophy_type' = 'bronze') as bronze_count,
  COUNT(*) FILTER (WHERE a.metadata->>'psn_trophy_type' = 'silver') as silver_count,
  COUNT(*) FILTER (WHERE a.metadata->>'psn_trophy_type' = 'gold') as gold_count,
  COUNT(*) FILTER (WHERE a.metadata->>'psn_trophy_type' = 'platinum') as platinum_count
FROM user_achievements ua
JOIN games g ON g.platform_id = ua.platform_id AND g.platform_game_id = ua.platform_game_id
LEFT JOIN achievements a ON 
  a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id 
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND g.name ILIKE '%dishonored%'
GROUP BY ua.platform_id, ua.platform_game_id, g.name;

-- Check what get_user_grouped_games returns for Dishonored
SELECT 
  name,
  platforms
FROM get_user_grouped_games('84b60ad6-cb2c-484f-8953-bf814551fd7a')
WHERE name ILIKE '%dishonored%';
