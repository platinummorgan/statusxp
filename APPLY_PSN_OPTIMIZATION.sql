-- Run this in Supabase SQL Editor to optimize PSN Leaderboard
-- https://supabase.com/dashboard/project/ksriqcmumjkemtfjuedm/sql/new

-- Drop the existing view
DROP VIEW IF EXISTS public.psn_leaderboard_cache CASCADE;

-- Create materialized view for PSN leaderboard (much faster!)
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
WHERE ua.platform_id IN (1, 2, 5, 9)
  AND p.show_on_leaderboard = true
GROUP BY ua.user_id, p.psn_online_id, p.display_name, p.username, p.psn_avatar_url
HAVING COUNT(*) > 0
ORDER BY 
  SUM(CASE WHEN a.is_platinum = true THEN 1 ELSE 0 END) DESC,
  SUM(CASE WHEN (a.metadata->>'psn_trophy_type' = 'gold') THEN 1 ELSE 0 END) DESC,
  SUM(CASE WHEN (a.metadata->>'psn_trophy_type' = 'silver') THEN 1 ELSE 0 END) DESC;

-- Add unique index on user_id (required for CONCURRENT refresh)
CREATE UNIQUE INDEX IF NOT EXISTS idx_psn_leaderboard_cache_user_id 
  ON psn_leaderboard_cache(user_id);

-- Add index for fast sorting by platinum count
CREATE INDEX IF NOT EXISTS idx_psn_leaderboard_cache_platinum 
  ON psn_leaderboard_cache(platinum_count DESC, gold_count DESC);

-- Initial data population
REFRESH MATERIALIZED VIEW psn_leaderboard_cache;

-- Create refresh function
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

-- Schedule hourly refresh (removes old job first)
SELECT cron.unschedule(jobid) 
FROM cron.job 
WHERE jobname = 'refresh_psn_leaderboard';

SELECT cron.schedule(
  'refresh_psn_leaderboard',
  '0 * * * *',
  $$SELECT refresh_psn_leaderboard_cache()$$
);

-- Verify it worked
SELECT 
  COUNT(*) as total_users,
  MAX(platinum_count) as max_platinums,
  SUM(platinum_count) as total_platinums
FROM psn_leaderboard_cache;
