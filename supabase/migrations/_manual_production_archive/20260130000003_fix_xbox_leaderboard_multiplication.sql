-- Fix Xbox Leaderboard Gamerscore Multiplication Bug
-- Date: 2026-01-30
-- Issue: View joins through achievements, causing current_score to be summed per achievement
-- Example: 1000G game with 10 achievements = 10,000G (10x multiplication)
-- Fix: Aggregate per-game FIRST, then calculate totals

BEGIN;

DROP VIEW IF EXISTS public.xbox_leaderboard_cache CASCADE;

CREATE OR REPLACE VIEW public.xbox_leaderboard_cache 
WITH (security_invoker = true) AS
WITH xbox_user_stats AS (
  -- First aggregate per game to avoid multiplication
  SELECT 
    up.user_id,
    -- Sum gamerscore per game (ONE value per game)
    SUM(up.current_score) as total_gamerscore,
    -- Count unique games
    COUNT(DISTINCT (up.platform_id, up.platform_game_id)) as total_games
  FROM user_progress up
  WHERE up.platform_id IN (10, 11, 12) -- Xbox 360, One, Series X/S
    AND up.current_score > 0
  GROUP BY up.user_id
),
xbox_achievement_count AS (
  -- Count total achievements separately
  SELECT 
    ua.user_id,
    COUNT(*) as achievement_count
  FROM user_achievements ua
  WHERE ua.platform_id IN (10, 11, 12)
  GROUP BY ua.user_id
)
SELECT 
  xus.user_id,
  COALESCE(p.xbox_gamertag, p.display_name, p.username, 'Player') as display_name,
  p.xbox_avatar_url as avatar_url,
  COALESCE(xac.achievement_count, 0) as achievement_count,
  xus.total_games,
  xus.total_gamerscore as gamerscore,
  now() as updated_at
FROM xbox_user_stats xus
JOIN profiles p ON p.id = xus.user_id
LEFT JOIN xbox_achievement_count xac ON xac.user_id = xus.user_id
WHERE p.show_on_leaderboard = true
  AND xus.total_gamerscore > 0
ORDER BY xus.total_gamerscore DESC, xac.achievement_count DESC, xus.total_games DESC;

COMMIT;

-- Verification: Check if gamerscore looks reasonable
-- Should see values like 6775, not 167755
-- SELECT user_id, display_name, gamerscore, achievement_count, total_games
-- FROM xbox_leaderboard_cache
-- ORDER BY gamerscore DESC
-- LIMIT 20;
