-- Recover the final sync status after durable leaderboard work completes.
-- A background worker can finish after the foreground sync already returned.
BEGIN;
SET LOCAL lock_timeout='5s';
CREATE FUNCTION statusxp_private.recover_finished_psn_refreshes()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE repaired integer;
BEGIN
UPDATE public.psn_sync_logs l
SET status = 'completed',
    error_message = 'Leaderboard refresh recovered automatically at ' || clock_timestamp()::text
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

GET DIAGNOSTICS repaired=ROW_COUNT;

UPDATE public.profiles_private p
SET psn_sync_status = 'success', psn_sync_progress = 100,
    psn_sync_error = NULL, last_psn_sync_at = l.completed_at
FROM public.psn_sync_logs l
WHERE p.id = l.user_id AND p.psn_sync_status = 'error'
  AND p.psn_sync_error = 'Sync data saved; leaderboard refresh pending. A background retry is queued.'
  AND l.status = 'completed'
  AND l.error_message LIKE 'Leaderboard refresh recovered automatically at %'
  AND NOT EXISTS (SELECT 1 FROM public.psn_sync_logs newer
    WHERE newer.user_id = l.user_id AND newer.id > l.id);

RETURN repaired;
END $$;
REVOKE ALL ON FUNCTION statusxp_private.recover_finished_psn_refreshes() FROM PUBLIC,anon,authenticated,service_role;
SELECT cron.schedule('recover-finished-psn-refreshes','* * * * *','SELECT statusxp_private.recover_finished_psn_refreshes();');
SELECT statusxp_private.recover_finished_psn_refreshes();
COMMIT;
