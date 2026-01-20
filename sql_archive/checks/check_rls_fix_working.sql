-- Check if achievements are being written to user_achievements (RLS fix test)
-- User ID: 84b60ad6-cb2c-484f-8953-bf814551fd7a

-- Compare before/after achievement counts
SELECT 
  'Achievement Storage Comparison' as section,
  'BEFORE: 9399 PSN, 309 Xbox, 581 Steam = 10,289 total' as before_sync,
  COUNT(*) FILTER (WHERE a.platform = 'psn') as psn_now,
  COUNT(*) FILTER (WHERE a.platform = 'xbox') as xbox_now,
  COUNT(*) FILTER (WHERE a.platform = 'steam') as steam_now,
  COUNT(*) as total_now
FROM user_achievements ua
INNER JOIN achievements a ON a.id = ua.achievement_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Check specifically for the 5 removed PSN games - did their achievements get re-added?
SELECT 
  'PSN Test Games - Achievements' as section,
  gt.name,
  COUNT(ua.id) as achievements_stored
FROM game_titles gt
LEFT JOIN achievements a ON a.game_title_id = gt.id AND a.platform = 'psn'
LEFT JOIN user_achievements ua ON ua.achievement_id = a.id AND ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
WHERE gt.name IN ('Gems of War', 'DRAGON QUEST HEROES II', 'Terraria', 'DOGFIGHTER -WW2-', 'Sky: Children of the Light')
GROUP BY gt.name
ORDER BY gt.name;
