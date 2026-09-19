-- LOCAL TEST DATABASE ONLY. Apply the queue migration first with fixture roles
-- anon/authenticated/service_role (BYPASSRLS) and auth.users(id uuid primary key).
\set ON_ERROR_STOP on
BEGIN;
INSERT INTO auth.users(id) VALUES ('00000000-0000-0000-0000-000000000001');

DO $$
BEGIN
  IF has_table_privilege('anon', 'public.leaderboard_refresh_jobs', 'SELECT')
    OR has_table_privilege('authenticated', 'public.leaderboard_refresh_jobs', 'INSERT')
    OR has_function_privilege('authenticated', 'public.claim_leaderboard_refresh_job(uuid)', 'EXECUTE')
    OR has_function_privilege('anon', 'public.finish_leaderboard_refresh_job(uuid,uuid,text)', 'EXECUTE')
  THEN RAISE EXCEPTION 'Client privileges leaked'; END IF;
END $$;

SET LOCAL ROLE service_role;
INSERT INTO public.leaderboard_refresh_jobs(user_id, kind, source_platform)
VALUES ('00000000-0000-0000-0000-000000000001', 'statusxp', 'steam');
RESET ROLE;

DO $$
DECLARE first_job public.leaderboard_refresh_jobs;
        second_job public.leaderboard_refresh_jobs;
        third_job public.leaderboard_refresh_jobs;
BEGIN
  SELECT * INTO STRICT first_job FROM public.claim_leaderboard_refresh_job();
  IF first_job.attempts <> 1 OR first_job.lease_token IS NULL THEN
    RAISE EXCEPTION 'Claim did not establish lease'; END IF;
  IF EXISTS (SELECT FROM public.claim_leaderboard_refresh_job(first_job.id)) THEN
    RAISE EXCEPTION 'Live lease was claimed twice'; END IF;

  UPDATE public.leaderboard_refresh_jobs SET lease_until = now() - interval '1 second'
  WHERE id = first_job.id;
  SELECT * INTO STRICT second_job FROM public.claim_leaderboard_refresh_job(first_job.id);
  IF second_job.lease_token = first_job.lease_token OR second_job.attempts <> 2 THEN
    RAISE EXCEPTION 'Expired lease did not rotate'; END IF;
  IF public.finish_leaderboard_refresh_job(first_job.id, first_job.lease_token, NULL) THEN
    RAISE EXCEPTION 'Stale worker completed reclaimed job'; END IF;
  IF NOT public.finish_leaderboard_refresh_job(second_job.id, second_job.lease_token, 'retry') THEN
    RAISE EXCEPTION 'Failure was not acknowledged'; END IF;
  IF NOT EXISTS (SELECT FROM public.leaderboard_refresh_jobs WHERE id = second_job.id
    AND completed_at IS NULL AND last_error = 'retry' AND lease_token IS NULL
    AND next_attempt_at = now() + interval '60 seconds') THEN
    RAISE EXCEPTION 'Retry state/backoff not persisted'; END IF;
  IF EXISTS (SELECT FROM public.claim_leaderboard_refresh_job(second_job.id)) THEN
    RAISE EXCEPTION 'Job retried before backoff elapsed'; END IF;

  UPDATE public.leaderboard_refresh_jobs SET next_attempt_at = now() - interval '1 second'
  WHERE id = second_job.id;
  SELECT * INTO STRICT third_job FROM public.claim_leaderboard_refresh_job(second_job.id);
  IF NOT public.finish_leaderboard_refresh_job(third_job.id, third_job.lease_token, NULL) THEN
    RAISE EXCEPTION 'Successful refresh was not completed'; END IF;
  IF EXISTS (SELECT FROM public.claim_leaderboard_refresh_job(third_job.id)) THEN
    RAISE EXCEPTION 'Completed job was claimed again'; END IF;

  INSERT INTO public.leaderboard_refresh_jobs(user_id, kind, source_platform)
  VALUES (first_job.user_id, 'statusxp', 'xbox');
  IF NOT EXISTS (SELECT FROM public.claim_leaderboard_refresh_job()) THEN
    RAISE EXCEPTION 'A later sync obligation was lost'; END IF;
END $$;

SET LOCAL ROLE anon;
DO $$ BEGIN
  BEGIN
    PERFORM public.claim_leaderboard_refresh_job();
    RAISE EXCEPTION 'Anonymous execution succeeded';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
ROLLBACK;
\echo 'Queue permissions, lease recovery, stale acknowledgment, backoff, and new obligations passed'
