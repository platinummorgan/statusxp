-- Migration: Fix platform leaderboard caches to use platform-specific avatars
-- Updates PSN, Xbox, and Steam leaderboard caches to use platform-specific avatar URLs
-- instead of the generic avatar_url field

-- ============================================
-- PSN LEADERBOARD CACHE (VIEW)
-- ============================================
DROP VIEW IF EXISTS psn_leaderboard_cache;

CREATE VIEW psn_leaderboard_cache AS
SELECT 
  ua.user_id,
  COALESCE(p.psn_online_id, p.display_name, p.username, 'Player') AS display_name,
  p.psn_avatar_url AS avatar_url,  -- ✅ Use PSN-specific avatar
  SUM(CASE WHEN (a.metadata ->> 'psn_trophy_type') = 'bronze' THEN 1 ELSE 0 END) AS bronze_count,
  SUM(CASE WHEN (a.metadata ->> 'psn_trophy_type') = 'silver' THEN 1 ELSE 0 END) AS silver_count,
  SUM(CASE WHEN (a.metadata ->> 'psn_trophy_type') = 'gold' THEN 1 ELSE 0 END) AS gold_count,
  SUM(CASE WHEN a.is_platinum = true THEN 1 ELSE 0 END) AS platinum_count,
  COUNT(*) AS total_trophies,
  COUNT(DISTINCT a.platform_game_id) AS total_games,
  NOW() AS updated_at
FROM user_achievements ua
JOIN achievements a ON a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id 
  AND a.platform_achievement_id = ua.platform_achievement_id
JOIN profiles p ON p.id = ua.user_id
WHERE ua.platform_id IN (1, 2, 5, 9)  -- PS5, PS4, PS3, PSVITA
  AND p.show_on_leaderboard = true
GROUP BY ua.user_id, p.psn_online_id, p.display_name, p.username, p.psn_avatar_url
HAVING COUNT(*) > 0
ORDER BY 
  SUM(CASE WHEN a.is_platinum = true THEN 1 ELSE 0 END) DESC,
  SUM(CASE WHEN (a.metadata ->> 'psn_trophy_type') = 'gold' THEN 1 ELSE 0 END) DESC,
  SUM(CASE WHEN (a.metadata ->> 'psn_trophy_type') = 'silver' THEN 1 ELSE 0 END) DESC,
  SUM(CASE WHEN (a.metadata ->> 'psn_trophy_type') = 'bronze' THEN 1 ELSE 0 END) DESC;

COMMENT ON VIEW psn_leaderboard_cache IS 
  'PSN leaderboard showing all PSN platforms (PS5, PS4, PS3, PSVITA). Uses psn_avatar_url for platform-specific avatars.';

-- ============================================
-- XBOX LEADERBOARD CACHE (VIEW)
-- ============================================
DROP VIEW IF EXISTS xbox_leaderboard_cache CASCADE;

CREATE VIEW xbox_leaderboard_cache AS
SELECT 
  ua.user_id,
  COALESCE(p.xbox_gamertag, p.display_name, p.username, 'Player') AS display_name,
  p.xbox_avatar_url AS avatar_url,  -- ✅ Use Xbox-specific avatar
  COUNT(*) AS achievement_count,
  COUNT(DISTINCT a.platform_game_id) AS total_games,
  COALESCE(SUM(up.current_score), 0) AS gamerscore,
  NOW() AS updated_at
FROM user_achievements ua
JOIN achievements a ON a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id 
  AND a.platform_achievement_id = ua.platform_achievement_id
JOIN profiles p ON p.id = ua.user_id
LEFT JOIN user_progress up ON up.user_id = ua.user_id 
  AND up.platform_id = a.platform_id 
  AND up.platform_game_id = a.platform_game_id
WHERE ua.platform_id IN (10, 11, 12)  -- Xbox360, XboxOne, XboxSeriesX
  AND p.show_on_leaderboard = true
GROUP BY ua.user_id, p.xbox_gamertag, p.display_name, p.username, p.xbox_avatar_url
HAVING COUNT(*) > 0
ORDER BY 
  COALESCE(SUM(up.current_score), 0) DESC,
  COUNT(*) DESC,
  COUNT(DISTINCT a.platform_game_id) DESC;

COMMENT ON VIEW xbox_leaderboard_cache IS 
  'Xbox leaderboard showing all Xbox platforms (360, One, Series X/S). Uses xbox_avatar_url for platform-specific avatars. Uses V2 schema with user_progress for gamerscore.';

-- ============================================
-- STEAM LEADERBOARD CACHE (VIEW)
-- ============================================
DROP VIEW IF EXISTS steam_leaderboard_cache CASCADE;

CREATE VIEW steam_leaderboard_cache AS
SELECT 
  ua.user_id,
  COALESCE(p.steam_display_name, p.display_name, p.username, 'Player') AS display_name,
  p.steam_avatar_url AS avatar_url,  -- ✅ Use Steam-specific avatar
  COUNT(*) AS achievement_count,
  COUNT(DISTINCT a.platform_game_id) AS total_games,
  NOW() AS updated_at
FROM user_achievements ua
JOIN achievements a ON a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id 
  AND a.platform_achievement_id = ua.platform_achievement_id
JOIN profiles p ON p.id = ua.user_id
WHERE ua.platform_id = 4  -- Steam
  AND p.show_on_leaderboard = true
GROUP BY ua.user_id, p.steam_display_name, p.display_name, p.username, p.steam_avatar_url
HAVING COUNT(*) > 0
ORDER BY 
  COUNT(*) DESC,
  COUNT(DISTINCT a.platform_game_id) DESC;

COMMENT ON VIEW steam_leaderboard_cache IS 
  'Steam leaderboard showing Steam achievements. Uses steam_avatar_url for platform-specific avatars. Uses V2 schema.';

-- ============================================
-- DROP OLD REFRESH FUNCTIONS (NO LONGER NEEDED)
-- ============================================
-- These functions were used to refresh the old TABLE-based caches
-- Now we use VIEWs that are always up-to-date
DROP FUNCTION IF EXISTS refresh_psn_leaderboard_cache();
DROP FUNCTION IF EXISTS refresh_xbox_leaderboard_cache();
DROP FUNCTION IF EXISTS refresh_steam_leaderboard_cache();

COMMENT ON SCHEMA public IS 
  'Platform leaderboard caches migrated to VIEWs in migration 1011. No refresh functions needed - VIEWs always show current data.';
