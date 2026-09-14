\ir ../apple-store-notifications/entitlement_test.sql
INSERT INTO auth.users VALUES('00000000-0000-4000-8000-000000000098');
SELECT public.bind_store_subscription('00000000-0000-4000-8000-000000000098','app_store','production:900098',NULL,true);
\ir ../../migrations/20260912150000_entitlement_reconciliation_jobs.sql
DO $$ BEGIN ASSERT (SELECT count(*)=1 FROM public.entitlement_reconciliation_jobs); END $$;
UPDATE public.entitlement_reconciliation_jobs SET next_attempt_at=now()+interval '4 hours';
\ir ../../migrations/20260912150000_entitlement_reconciliation_jobs.sql
DO $$ BEGIN ASSERT (SELECT next_attempt_at>now()+interval '3 hours 59 minutes' FROM public.entitlement_reconciliation_jobs); END $$;
DELETE FROM public.store_subscription_bindings WHERE platform='app_store' AND subscription_key='production:900098';
DELETE FROM auth.users WHERE id='00000000-0000-4000-8000-000000000098';
BEGIN;
INSERT INTO auth.users VALUES('00000000-0000-4000-8000-000000000001');
INSERT INTO public.profiles(id) VALUES('00000000-0000-4000-8000-000000000001');
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
DO $$
DECLARE u uuid:=auth.uid(); first_job public.entitlement_reconciliation_jobs%ROWTYPE; next_job public.entitlement_reconciliation_jobs%ROWTYPE;
BEGIN
  PERFORM public.bind_store_subscription(u,'app_store','production:10001',NULL,true);
  PERFORM public.bind_store_subscription(u,'app_store','sandbox:10001',NULL,true);
  PERFORM public.bind_verified_twitch_account(u,'20');
  ASSERT (SELECT count(*)=3 FROM public.entitlement_reconciliation_jobs);
  SELECT * INTO first_job FROM public.claim_entitlement_reconciliation(ARRAY['apple'],false);
  ASSERT first_job.subject='production:10001'; ASSERT first_job.attempts=1;
  ASSERT NOT EXISTS(SELECT 1 FROM public.claim_entitlement_reconciliation(ARRAY['apple'],false));
  ASSERT NOT public.finish_entitlement_reconciliation('apple',first_job.subject,gen_random_uuid(),true);
  ASSERT public.finish_entitlement_reconciliation('apple',first_job.subject,first_job.lease_token,false);
  ASSERT (SELECT last_failure_at IS NOT NULL AND next_attempt_at>now()+interval '45 seconds' FROM public.entitlement_reconciliation_jobs WHERE provider='apple' AND subject=first_job.subject);
  ASSERT NOT EXISTS(SELECT 1 FROM public.claim_entitlement_reconciliation(ARRAY['apple'],false));
  UPDATE public.entitlement_reconciliation_jobs SET next_attempt_at=now() WHERE provider='apple' AND subject=first_job.subject;
  SELECT * INTO next_job FROM public.claim_entitlement_reconciliation(ARRAY['apple'],false);
  ASSERT next_job.attempts=2;
  ASSERT public.finish_entitlement_reconciliation('apple',next_job.subject,next_job.lease_token,false);
  ASSERT (SELECT next_attempt_at>now()+interval '100 seconds' FROM public.entitlement_reconciliation_jobs WHERE provider='apple' AND subject=first_job.subject);
  UPDATE public.entitlement_reconciliation_jobs SET next_attempt_at=now() WHERE provider='apple' AND subject=first_job.subject;
  SELECT * INTO first_job FROM public.claim_entitlement_reconciliation(ARRAY['apple'],false);
  UPDATE public.entitlement_reconciliation_jobs SET lease_expires_at=clock_timestamp() WHERE provider='apple' AND subject=first_job.subject;
  SELECT * INTO next_job FROM public.claim_entitlement_reconciliation(ARRAY['apple'],false);
  ASSERT next_job.lease_token<>first_job.lease_token;
  ASSERT NOT public.finish_entitlement_reconciliation('apple',first_job.subject,first_job.lease_token,true);
  ASSERT public.finish_entitlement_reconciliation('apple',next_job.subject,next_job.lease_token,true);
  ASSERT (SELECT attempts=0 AND lease_token IS NULL AND last_success_at IS NOT NULL AND next_attempt_at>now()+interval '5 hours 59 minutes'
    FROM public.entitlement_reconciliation_jobs WHERE provider='apple' AND subject=first_job.subject);
  SELECT * INTO next_job FROM public.claim_entitlement_reconciliation(ARRAY['apple'],true);
  ASSERT next_job.subject='sandbox:10001';
  SELECT * INTO next_job FROM public.claim_entitlement_reconciliation(ARRAY['twitch'],false);
  ASSERT next_job.subject='20';
  PERFORM public.disconnect_my_twitch_account();
  ASSERT NOT EXISTS(SELECT 1 FROM public.entitlement_reconciliation_jobs WHERE provider='twitch');
  ASSERT NOT public.finish_entitlement_reconciliation('twitch','20',next_job.lease_token,true);
  ASSERT NOT has_table_privilege('authenticated','public.entitlement_reconciliation_jobs','SELECT');
  ASSERT NOT has_function_privilege('anon','public.claim_entitlement_reconciliation(text[],boolean)','EXECUTE');
  ASSERT NOT has_function_privilege('authenticated','public.finish_entitlement_reconciliation(text,text,uuid,boolean)','EXECUTE');
  DELETE FROM auth.users WHERE id=u;
  ASSERT (SELECT count(*)=0 FROM public.entitlement_reconciliation_jobs);
  ASSERT (SELECT count(*)=2 FROM public.store_subscription_bindings WHERE user_id IS NULL);
END $$;
ROLLBACK;
\echo Reconciliation queue: binding lifecycle, provider/sandbox filtering, leases, retry backoff, recurring success and cleanup passed.
