-- Enable pg_cron extension for scheduled jobs
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Create function to refresh leaderboard cache
CREATE OR REPLACE FUNCTION refresh_leaderboard_cache()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY leaderboard_cache;
END;
$$;

-- Schedule automatic refresh every 15 minutes
SELECT cron.schedule(
  'refresh-leaderboard-cache',
  '*/15 * * * *',
  $$SELECT refresh_leaderboard_cache();$$
);

-- Initial refresh
SELECT refresh_leaderboard_cache();

-- Verify cron job is scheduled
SELECT * FROM cron.job WHERE jobname = 'refresh-leaderboard-cache';
