-- Run after the background-service timeout migration. One global PSN refresh
-- satisfies all PSN obligations already queued when this transaction started.
BEGIN;
SET LOCAL statement_timeout = '60s';
SET LOCAL lock_timeout = '5s';
SELECT public.refresh_psn_leaderboard_cache();

UPDATE public.leaderboard_refresh_jobs
SET completed_at = clock_timestamp(), last_error = NULL,
    lease_token = NULL, lease_until = NULL
WHERE kind = 'psn' AND completed_at IS NULL
  AND created_at <= transaction_timestamp()
  AND (lease_until IS NULL OR lease_until <= clock_timestamp());

-- Only repair failures caused exclusively by the now-completed refresh jobs.
-- Keep the original sync finish timestamp and an audit note on each log.
UPDATE public.psn_sync_logs l
SET status = 'completed',
    error_message = 'Leaderboard refresh recovered at ' || clock_timestamp()::text
      || '; original error: ' || l.error_message
WHERE l.status = 'failed'
  AND l.error_message = 'Sync data saved; leaderboard refresh pending. A background retry is queued.'
  AND l.completed_at IS NOT NULL
  AND EXISTS (SELECT 1 FROM public.leaderboard_refresh_jobs j
    WHERE j.user_id = l.user_id AND j.source_platform = 'psn'
      AND j.kind = 'statusxp' AND j.completed_at IS NOT NULL
      AND j.created_at BETWEEN l.started_at AND l.completed_at)
  AND EXISTS (SELECT 1 FROM public.leaderboard_refresh_jobs j
    WHERE j.user_id = l.user_id AND j.source_platform = 'psn'
      AND j.kind = 'psn' AND j.completed_at IS NOT NULL
      AND j.created_at BETWEEN l.started_at AND l.completed_at)
  AND NOT EXISTS (SELECT 1 FROM public.leaderboard_refresh_jobs j
    WHERE j.user_id = l.user_id AND j.source_platform = 'psn'
      AND j.completed_at IS NULL
      AND j.created_at BETWEEN l.started_at AND l.completed_at);

UPDATE public.profiles_private p
SET psn_sync_status = 'success', psn_sync_progress = 100,
    psn_sync_error = NULL, last_psn_sync_at = l.completed_at
FROM public.psn_sync_logs l
WHERE p.id = l.user_id AND p.psn_sync_status = 'error'
  AND p.psn_sync_error = 'Sync data saved; leaderboard refresh pending. A background retry is queued.'
  AND l.status = 'completed'
  AND l.error_message LIKE 'Leaderboard refresh recovered at %'
  AND NOT EXISTS (SELECT 1 FROM public.psn_sync_logs newer
    WHERE newer.user_id = l.user_id AND newer.id > l.id);
COMMIT;
