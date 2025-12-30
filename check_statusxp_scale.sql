-- Check if base_status_xp values are at 0.5 scale or 1.0 scale
-- Sample some achievements to see their current base_status_xp values
SELECT 
  platform,
  rarity_global,
  COUNT(*) as achievement_count,
  MIN(base_status_xp) as min_statusxp,
  MAX(base_status_xp) as max_statusxp,
  AVG(base_status_xp) as avg_statusxp
FROM achievements
WHERE rarity_global IS NOT NULL
GROUP BY platform, rarity_global
ORDER BY platform, rarity_global DESC;

-- Check a specific user's game to see what's in the database
SELECT 
  ug.id,
  gt.title,
  pl.code as platform,
  ug.statusxp_raw,
  ug.statusxp_effective,
  ug.stack_multiplier,
  ug.base_completed
FROM user_games ug
JOIN game_titles gt ON gt.id = ug.game_title_id
JOIN platforms pl ON pl.id = ug.platform_id
JOIN profiles p ON p.id = ug.user_id
WHERE p.psn_online_id = 'Dex-Morgan'
ORDER BY ug.statusxp_effective DESC
LIMIT 10;
