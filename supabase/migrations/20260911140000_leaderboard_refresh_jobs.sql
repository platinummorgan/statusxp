-- Apply manually before deploying the refresh worker. Do not db push --linked.
BEGIN;

CREATE TABLE IF NOT EXISTS public.leaderboard_refresh_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  kind text NOT NULL CHECK (kind IN ('statusxp', 'psn')),
  source_platform text NOT NULL CHECK (source_platform IN ('psn', 'xbox', 'steam')),
  attempts integer NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  next_attempt_at timestamptz NOT NULL DEFAULT now(),
  lease_token uuid,
  lease_until timestamptz,
  last_error text,
  created_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz
);
CREATE INDEX IF NOT EXISTS leaderboard_refresh_jobs_due
  ON public.leaderboard_refresh_jobs(next_attempt_at, created_at)
  WHERE completed_at IS NULL;
ALTER TABLE public.leaderboard_refresh_jobs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.leaderboard_refresh_jobs FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT ON public.leaderboard_refresh_jobs TO service_role;

CREATE OR REPLACE FUNCTION public.claim_leaderboard_refresh_job(p_job_id uuid DEFAULT NULL)
RETURNS SETOF public.leaderboard_refresh_jobs
LANGUAGE sql SECURITY DEFINER SET search_path = '' AS $$
  UPDATE public.leaderboard_refresh_jobs AS job
  SET lease_token = gen_random_uuid(), lease_until = now() + interval '5 minutes',
      attempts = job.attempts + 1
  WHERE job.id = (
    SELECT candidate.id FROM public.leaderboard_refresh_jobs AS candidate
    WHERE candidate.completed_at IS NULL
      AND candidate.next_attempt_at <= now()
      AND (candidate.lease_until IS NULL OR candidate.lease_until <= now())
      AND (p_job_id IS NULL OR candidate.id = p_job_id)
    ORDER BY candidate.next_attempt_at, candidate.created_at, candidate.id
    FOR UPDATE SKIP LOCKED LIMIT 1
  ) RETURNING job.*;
$$;

CREATE OR REPLACE FUNCTION public.finish_leaderboard_refresh_job(
  p_job_id uuid, p_lease_token uuid, p_error text DEFAULT NULL
) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  UPDATE public.leaderboard_refresh_jobs
  SET completed_at = CASE WHEN p_error IS NULL THEN now() ELSE NULL END,
      last_error = left(p_error, 200),
      next_attempt_at = CASE WHEN p_error IS NULL THEN next_attempt_at ELSE
        now() + make_interval(secs => least(3600, 30 * power(2, least(attempts - 1, 7)))::int) END,
      lease_token = NULL, lease_until = NULL
  WHERE id = p_job_id AND lease_token = p_lease_token AND completed_at IS NULL;
  RETURN FOUND;
END;
$$;

REVOKE ALL ON FUNCTION public.claim_leaderboard_refresh_job(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.finish_leaderboard_refresh_job(uuid, uuid, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_leaderboard_refresh_job(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.finish_leaderboard_refresh_job(uuid, uuid, text) TO service_role;
COMMIT;
