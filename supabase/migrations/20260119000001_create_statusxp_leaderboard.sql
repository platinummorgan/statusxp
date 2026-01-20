-- ============================================================================
-- CREATE STATUSXP UNIFIED LEADERBOARD CACHE
-- ============================================================================
-- The app expects a 'leaderboard_cache' table for the StatusXP tab
-- This combines data from all platforms into a single leaderboard

BEGIN;

-- Create the unified StatusXP leaderboard cache table
CREATE TABLE IF NOT EXISTS public.leaderboard_cache (
  user_id uuid NOT NULL PRIMARY KEY,
  total_statusxp bigint NOT NULL DEFAULT 0,
  total_game_entries integer NOT NULL DEFAULT 0,
  last_updated timestamp with time zone DEFAULT now(),
  CONSTRAINT leaderboard_cache_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);

-- Create index for fast sorting by StatusXP
CREATE INDEX IF NOT EXISTS idx_leaderboard_cache_statusxp 
  ON public.leaderboard_cache(total_statusxp DESC);

-- Populate the leaderboard cache with current StatusXP data
-- This aggregates from user_progress across all platforms
INSERT INTO public.leaderboard_cache (user_id, total_statusxp, total_game_entries, last_updated)
SELECT 
  up.user_id,
  -- Sum up all StatusXP-equivalent scores across platforms
  SUM(
    CASE 
      -- PSN: Calculate from trophy breakdown in metadata
      WHEN up.platform_id = 1 THEN 
        COALESCE((up.metadata->>'bronze_trophies')::integer, 0) * 25 +
        COALESCE((up.metadata->>'silver_trophies')::integer, 0) * 50 +
        COALESCE((up.metadata->>'gold_trophies')::integer, 0) * 100 +
        COALESCE((up.metadata->>'platinum_trophies')::integer, 0) * 1000
      -- Xbox: Use gamerscore directly
      WHEN up.platform_id IN (2,3,4) THEN COALESCE(up.current_score, 0)
      -- Steam: Estimate from achievement count (25 points per achievement)
      WHEN up.platform_id = 5 THEN COALESCE(up.achievements_earned, 0) * 25
      ELSE COALESCE(up.current_score, 0)
    END
  ) as total_statusxp,
  COUNT(DISTINCT CONCAT(up.platform_id, '-', up.platform_game_id)) as total_game_entries,
  NOW() as last_updated
FROM user_progress up
JOIN profiles p ON p.id = up.user_id
WHERE p.merged_into_user_id IS NULL
  AND p.show_on_leaderboard = true
GROUP BY up.user_id
HAVING SUM(
    CASE 
      WHEN up.platform_id = 1 THEN 
        COALESCE((up.metadata->>'bronze_trophies')::integer, 0) * 25 +
        COALESCE((up.metadata->>'silver_trophies')::integer, 0) * 50 +
        COALESCE((up.metadata->>'gold_trophies')::integer, 0) * 100 +
        COALESCE((up.metadata->>'platinum_trophies')::integer, 0) * 1000
      WHEN up.platform_id IN (2,3,4) THEN COALESCE(up.current_score, 0)
      WHEN up.platform_id = 5 THEN COALESCE(up.achievements_earned, 0) * 25
      ELSE COALESCE(up.current_score, 0)
    END
  ) > 0
ON CONFLICT (user_id) 
DO UPDATE SET
  total_statusxp = EXCLUDED.total_statusxp,
  total_game_entries = EXCLUDED.total_game_entries,
  last_updated = NOW();

COMMIT;

-- Verification
SELECT 
  'leaderboard_cache' as table_name,
  COUNT(*) as total_users,
  SUM(total_statusxp) as total_statusxp_points,
  MAX(total_statusxp) as highest_score,
  MAX(total_game_entries) as most_games
FROM leaderboard_cache;

-- Show top 10 users
SELECT 
  p.username,
  p.display_name,
  lc.total_statusxp,
  lc.total_game_entries,
  lc.last_updated
FROM leaderboard_cache lc
JOIN profiles p ON p.id = lc.user_id
ORDER BY lc.total_statusxp DESC
LIMIT 10;

SELECT '✅ StatusXP leaderboard cache created!' as status;
