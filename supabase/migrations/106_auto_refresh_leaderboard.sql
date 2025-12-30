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
-- This ensures leaderboard data is never more than 15 minutes stale
SELECT cron.schedule(
  'refresh-leaderboard-cache',
  '*/15 * * * *',  -- Every 15 minutes
  $$SELECT refresh_leaderboard_cache();$$
);

-- Also create a trigger to refresh when user_games are updated
-- This is a simpler approach but might be slower with many updates
CREATE OR REPLACE FUNCTION trigger_refresh_leaderboard()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  -- Use pg_notify to signal that a refresh is needed
  -- A background job will pick this up and refresh
  PERFORM pg_notify('leaderboard_refresh_needed', '');
  RETURN NULL;
END;
$$;

-- Create trigger on user_games table
-- Note: This only notifies, the actual refresh happens via cron
-- to avoid performance issues with frequent refreshes
DROP TRIGGER IF EXISTS user_games_leaderboard_refresh ON user_games;
CREATE TRIGGER user_games_leaderboard_refresh
AFTER INSERT OR UPDATE OR DELETE ON user_games
FOR EACH STATEMENT
EXECUTE FUNCTION trigger_refresh_leaderboard();

-- Initial refresh
SELECT refresh_leaderboard_cache();

-- Verify cron job is scheduled
SELECT * FROM cron.job WHERE jobname = 'refresh-leaderboard-cache';
