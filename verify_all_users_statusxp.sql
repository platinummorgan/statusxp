-- Comprehensive StatusXP verification for all users across all platforms
SELECT 
  p.id as user_id,
  COALESCE(p.psn_online_id, p.xbox_gamertag, p.steam_display_name, p.display_name, 'Unknown') as username,
  au.email,
  
  -- PSN StatusXP (platforms 1, 2, 4, 5 = PS3, PS4, PS5, PSVITA)
  COALESCE(SUM(CASE WHEN ug.platform_id IN (1, 2, 4, 5) THEN ug.statusxp_effective ELSE 0 END), 0) as psn_statusxp,
  COUNT(DISTINCT CASE WHEN ug.platform_id IN (1, 2, 4, 5) THEN ug.game_title_id END) as psn_games,
  
  -- Xbox StatusXP (platform 11 and others with XBOX)
  COALESCE(SUM(CASE WHEN pl.code LIKE '%XBOX%' THEN ug.statusxp_effective ELSE 0 END), 0) as xbox_statusxp,
  COUNT(DISTINCT CASE WHEN pl.code LIKE '%XBOX%' THEN ug.game_title_id END) as xbox_games,
  
  -- Steam StatusXP
  COALESCE(SUM(CASE WHEN pl.code = 'Steam' THEN ug.statusxp_effective ELSE 0 END), 0) as steam_statusxp,
  COUNT(DISTINCT CASE WHEN pl.code = 'Steam' THEN ug.game_title_id END) as steam_games,
  
  -- Total across all platforms
  COALESCE(SUM(ug.statusxp_effective), 0) as total_statusxp,
  COUNT(DISTINCT ug.game_title_id) as total_unique_games,
  
  -- What leaderboard_cache shows
  lc.total_statusxp as cached_statusxp,
  
  -- Check if they match
  CASE 
    WHEN lc.total_statusxp IS NULL THEN 'NOT IN CACHE'
    WHEN ABS(COALESCE(SUM(ug.statusxp_effective), 0) - lc.total_statusxp) < 1 THEN '✅ MATCH'
    ELSE '❌ MISMATCH'
  END as status
  
FROM profiles p
LEFT JOIN auth.users au ON au.id = p.id
LEFT JOIN user_games ug ON ug.user_id = p.id
LEFT JOIN platforms pl ON pl.id = ug.platform_id
LEFT JOIN leaderboard_cache lc ON lc.user_id = p.id
WHERE p.created_at >= '2025-12-01'  -- Only recent users
GROUP BY p.id, p.psn_online_id, p.xbox_gamertag, p.steam_display_name, p.display_name, au.email, lc.total_statusxp
HAVING COUNT(ug.id) > 0  -- Only users with games
ORDER BY total_statusxp DESC;
