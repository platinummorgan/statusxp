-- Migration: Fix PSN leaderboard cache to count ALL PSN platforms and use is_platinum field
-- Recreates the view to:
-- 1. Count platform_id IN (1,2,5,9) instead of only platform_id = 1 (PS5)
-- 2. Use a.is_platinum boolean instead of metadata JSON parsing

DROP VIEW IF EXISTS psn_leaderboard_cache;

CREATE VIEW psn_leaderboard_cache AS
SELECT 
  ua.user_id,
  COALESCE(p.display_name, p.username, 'Player') AS display_name,
  p.avatar_url,
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
GROUP BY ua.user_id, p.display_name, p.username, p.avatar_url
HAVING COUNT(*) > 0
ORDER BY 
  SUM(CASE WHEN a.is_platinum = true THEN 1 ELSE 0 END) DESC,
  SUM(CASE WHEN (a.metadata ->> 'psn_trophy_type') = 'gold' THEN 1 ELSE 0 END) DESC,
  SUM(CASE WHEN (a.metadata ->> 'psn_trophy_type') = 'silver' THEN 1 ELSE 0 END) DESC,
  SUM(CASE WHEN (a.metadata ->> 'psn_trophy_type') = 'bronze' THEN 1 ELSE 0 END) DESC;

COMMENT ON VIEW psn_leaderboard_cache IS 
  'PSN leaderboard showing all PSN platforms (PS5, PS4, PS3, PSVITA). Counts platinum trophies using is_platinum boolean field.';
