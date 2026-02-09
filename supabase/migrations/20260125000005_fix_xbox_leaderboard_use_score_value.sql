-- Migration: Fix Xbox leaderboard to show actual gamerscore from achievements.score_value
-- Date: 2026-01-25
-- 
-- Problem: After StatusXP migrations, user_progress.current_score stores StatusXP, not gamerscore
-- Xbox leaderboard was summing StatusXP (101k) instead of actual gamerscore (269k)
-- 
-- Solution: Update view to sum achievements.score_value (the actual Xbox gamerscore per achievement)

BEGIN;
DROP VIEW IF EXISTS xbox_leaderboard_cache CASCADE;
CREATE OR REPLACE VIEW xbox_leaderboard_cache AS
WITH xbox_user_stats AS (
  -- Count achievements and sum ACTUAL gamerscore from achievements.score_value
  -- Cap score_value at 1000 to filter out corrupt data (Xbox achievements max is typically 1000G)
  SELECT 
    ua.user_id,
    COUNT(*) AS achievement_count,
    COUNT(DISTINCT a.platform_game_id) AS total_games,
    COALESCE(SUM(LEAST(a.score_value, 1000)), 0) AS gamerscore  -- Cap at 1000G per achievement
  FROM user_achievements ua
  JOIN achievements a ON 
    a.platform_id = ua.platform_id 
    AND a.platform_game_id = ua.platform_game_id 
    AND a.platform_achievement_id = ua.platform_achievement_id
  WHERE ua.platform_id IN (10, 11, 12) -- Xbox 360, One, Series X/S
  GROUP BY ua.user_id
)
SELECT 
  xus.user_id,
  COALESCE(p.xbox_gamertag, p.display_name, p.username, 'Player') AS display_name,
  p.xbox_avatar_url AS avatar_url,
  xus.achievement_count,
  xus.total_games,
  xus.gamerscore,
  NOW() AS updated_at
FROM xbox_user_stats xus
JOIN profiles p ON p.id = xus.user_id
WHERE p.show_on_leaderboard = true
  AND xus.achievement_count > 0
ORDER BY 
  xus.gamerscore DESC,
  xus.achievement_count DESC,
  xus.total_games DESC;
COMMENT ON VIEW xbox_leaderboard_cache IS 'Xbox leaderboard showing all Xbox platforms (360, One, Series X/S). Sums actual gamerscore from achievements.score_value (not user_progress.current_score which is StatusXP).';
GRANT SELECT ON xbox_leaderboard_cache TO authenticated;
GRANT SELECT ON xbox_leaderboard_cache TO anon;
COMMIT;
