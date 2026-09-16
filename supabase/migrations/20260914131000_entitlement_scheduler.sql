-- Requires the server credential in Vault under this name, populated separately.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pg_net;
CREATE OR REPLACE FUNCTION public.run_entitlement_reconciliation()
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE token text; request_id bigint;
BEGIN
  IF NOT EXISTS(SELECT 1 FROM public.entitlement_reconciliation_jobs
    WHERE next_attempt_at<=now() AND (lease_expires_at IS NULL OR lease_expires_at<=now())) THEN
    RETURN NULL;
  END IF;
  SELECT decrypted_secret INTO token FROM vault.decrypted_secrets
    WHERE name='statusxp_entitlement_scheduler_key';
  IF token IS NULL THEN RAISE EXCEPTION 'Entitlement scheduler credential unavailable'; END IF;
  SELECT net.http_post(
    url:='https://ksriqcmumjkemtfjuedm.supabase.co/functions/v1/reconcile-premium-entitlements',
    headers:=jsonb_build_object('Content-Type','application/json','Authorization','Bearer '||token),
    body:='{}'::jsonb, timeout_milliseconds:=60000
  ) INTO request_id;
  RETURN request_id;
END;
$$;
REVOKE ALL ON FUNCTION public.run_entitlement_reconciliation() FROM PUBLIC,anon,authenticated,service_role;
SELECT cron.schedule('statusxp-entitlement-reconciliation','* * * * *','SELECT public.run_entitlement_reconciliation();');
COMMIT;
