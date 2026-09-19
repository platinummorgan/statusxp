-- Keep the scheduler credential in Vault and request memory, never pg_net's queue.
BEGIN;
CREATE EXTENSION IF NOT EXISTS http WITH SCHEMA extensions;
CREATE OR REPLACE FUNCTION public.run_entitlement_reconciliation()
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER
SET search_path=''
AS $$
DECLARE token text; response_status integer;
BEGIN
  IF NOT EXISTS(SELECT 1 FROM public.entitlement_reconciliation_jobs
    WHERE next_attempt_at<=now() AND (lease_expires_at IS NULL OR lease_expires_at<=now())) THEN
    RETURN NULL;
  END IF;
  SELECT decrypted_secret INTO token FROM vault.decrypted_secrets
    WHERE name='statusxp_entitlement_scheduler_key';
  IF token IS NULL THEN RAISE EXCEPTION 'Entitlement scheduler credential unavailable'; END IF;
  PERFORM extensions.http_set_curlopt('CURLOPT_TIMEOUT_MS','50000');
  PERFORM extensions.http_set_curlopt('CURLOPT_CONNECTTIMEOUT_MS','5000');
  SELECT status INTO response_status FROM extensions.http((
    'POST',
    'https://ksriqcmumjkemtfjuedm.supabase.co/functions/v1/reconcile-premium-entitlements',
    ARRAY[ROW('Authorization','Bearer '||token)::extensions.http_header],
    'application/json', '{}'
  )::extensions.http_request);
  IF response_status IS DISTINCT FROM 200 THEN
    RAISE EXCEPTION 'Entitlement reconciliation HTTP status %',response_status;
  END IF;
  RETURN response_status::bigint;
END;
$$;
REVOKE ALL ON FUNCTION public.run_entitlement_reconciliation() FROM PUBLIC,anon,authenticated,service_role;
COMMENT ON FUNCTION public.run_entitlement_reconciliation() IS
  'Cron-only reconciliation: NULL when idle, HTTP 200 on success; credentials never enter a request queue.';
COMMIT;
