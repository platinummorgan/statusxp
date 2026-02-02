-- Materialize PSN Leaderboard Cache for Performance
-- This migration converts the psn_leaderboard_cache view to a materialized view
-- and adds automatic refresh on a schedule

-- Drop the existing view
DROP VIEW IF EXISTS public.psn_leaderboard_cache CASCADE;

-- Create materialized view for PSN leaderboard
CREATE MATERIALIZED VIEW IF NOT EXISTS public.psn_leaderboard_cache AS
SELECT 
  ua.user_id,
  COALESCE(p.psn_online_id, p.display_name, p.username, 'Player') AS display_name,
  p.psn_avatar_url AS avatar_url,
  SUM(CASE WHEN (a.metadata->>'psn_trophy_type' = 'bronze') THEN 1 ELSE 0 END) AS bronze_count,
  SUM(CASE WHEN (a.metadata->>'psn_trophy_type' = 'silver') THEN 1 ELSE 0 END) AS silver_count,
  SUM(CASE WHEN (a.metadata->>'psn_trophy_type' = 'gold') THEN 1 ELSE 0 END) AS gold_count,
  SUM(CASE WHEN a.is_platinum = true THEN 1 ELSE 0 END) AS platinum_count,
  COUNT(*) AS total_trophies,
  COUNT(DISTINCT a.platform_game_id) AS total_games,
  now() AS updated_at
FROM public.user_achievements ua
JOIN public.achievements a 
  ON a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id 
  AND a.platform_achievement_id = ua.platform_achievement_id
JOIN public.profiles p ON p.id = ua.user_id
WHERE ua.platform_id IN (1, 2, 5, 9) -- PSN platforms (PS3, PS4, PS5, Vita)
  AND p.show_on_leaderboard = true
GROUP BY ua.user_id, p.psn_online_id, p.display_name, p.username, p.psn_avatar_url
HAVING COUNT(*) > 0
ORDER BY 
  SUM(CASE WHEN a.is_platinum = true THEN 1 ELSE 0 END) DESC,
  SUM(CASE WHEN (a.metadata->>'psn_trophy_type' = 'gold') THEN 1 ELSE 0 END) DESC,
  SUM(CASE WHEN (a.metadata->>'psn_trophy_type' = 'silver') THEN 1 ELSE 0 END) DESC,
  SUM(CASE WHEN (a.metadata->>'psn_trophy_type' = 'bronze') THEN 1 ELSE 0 END) DESC;

-- Add index for fast lookups
CREATE UNIQUE INDEX IF NOT EXISTS idx_psn_leaderboard_cache_user_id 
  ON psn_leaderboard_cache(user_id);

-- Add index for sorting by platinum count
CREATE INDEX IF NOT EXISTS idx_psn_leaderboard_cache_platinum 
  ON psn_leaderboard_cache(platinum_count DESC, gold_count DESC, silver_count DESC);

-- Create function to refresh the materialized view
CREATE OR REPLACE FUNCTION refresh_psn_leaderboard_cache()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY psn_leaderboard_cache;
  RAISE NOTICE 'PSN leaderboard cache refreshed at %', now();
END;
$$;

-- Grant permissions
GRANT SELECT ON psn_leaderboard_cache TO authenticated;
GRANT SELECT ON psn_leaderboard_cache TO anon;

-- Initial refresh to populate the materialized view
REFRESH MATERIALIZED VIEW psn_leaderboard_cache;

-- Schedule automatic refresh using pg_cron (every hour)
-- First, ensure any existing job is removed
SELECT cron.unschedule(jobid) 
FROM cron.job 
WHERE jobname = 'refresh_psn_leaderboard';

-- Schedule new job
SELECT cron.schedule(
  'refresh_psn_leaderboard',
  '0 * * * *', -- Every hour at :00
  $$SELECT refresh_psn_leaderboard_cache()$$
);

-- Add comment for documentation
COMMENT ON MATERIALIZED VIEW psn_leaderboard_cache IS 
'Materialized view for PSN leaderboard - refreshed hourly for optimal performance. 
Shows platinum, gold, silver, bronze trophy counts and total games for all PSN platforms.';
