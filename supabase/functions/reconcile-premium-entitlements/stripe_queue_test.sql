\ir google_queue_test.sql
INSERT INTO auth.users VALUES('00000000-0000-4000-8000-000000000091');
SELECT public.bind_stripe_customer('00000000-0000-4000-8000-000000000091','cus_seed');
INSERT INTO public.stripe_subscriptions VALUES('sub_seed','cus_seed','active',now()+interval '30 days',now());
\ir ../../migrations/20260912170000_stripe_reconciliation_jobs.sql
UPDATE public.entitlement_reconciliation_jobs SET next_attempt_at=now()+interval '4 hours' WHERE provider='stripe';
\ir ../../migrations/20260912170000_stripe_reconciliation_jobs.sql
DO $$ BEGIN
  ASSERT (SELECT count(*)=1 FROM public.entitlement_reconciliation_jobs WHERE provider='stripe');
  ASSERT (SELECT next_attempt_at>now()+interval '3 hours 59 minutes' FROM public.entitlement_reconciliation_jobs WHERE provider='stripe');
END $$;
DELETE FROM public.stripe_subscriptions WHERE subscription_id='sub_seed';
DELETE FROM auth.users WHERE id='00000000-0000-4000-8000-000000000091';
DELETE FROM public.stripe_customers WHERE customer_id='cus_seed';
BEGIN;
INSERT INTO auth.users VALUES('00000000-0000-4000-8000-000000000001');
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
DO $$
DECLARE u uuid:=auth.uid(); job public.entitlement_reconciliation_jobs%ROWTYPE; claim jsonb; competing jsonb; d jsonb; t timestamptz:=now();
BEGIN
  PERFORM public.bind_stripe_customer(u,'cus_scheduled');
  INSERT INTO public.stripe_subscriptions VALUES('sub_scheduled','cus_scheduled','active',t+interval '1 day',t);
  ASSERT (SELECT count(*)=1 FROM public.entitlement_reconciliation_jobs WHERE provider='stripe');
  SELECT * INTO job FROM public.claim_entitlement_reconciliation(ARRAY['stripe'],false);
  ASSERT job.subject='sub_scheduled' AND job.user_id=u;
  ASSERT NOT EXISTS(SELECT 1 FROM public.claim_entitlement_reconciliation(ARRAY['stripe'],false));
  claim:=public.claim_stripe_event('reconcile_test','subscription.reconciliation','subscription:sub_scheduled');
  ASSERT claim->>'state'='claimed';
  competing:=public.claim_stripe_event('evt_competing','customer.subscription.updated','subscription:sub_scheduled');
  ASSERT competing->>'state'='busy';
  d:=jsonb_build_object('kind','subscription','subscription_id','sub_scheduled','customer_id','cus_scheduled','user_id',u,'status','active','expires_at',t+interval '30 days');
  PERFORM public.finish_stripe_event('reconcile_test',(claim->>'token')::uuid,d);
  ASSERT (public.effective_premium_entitlement(u)->>'premium_expires_at')::timestamptz=t+interval '30 days';
  ASSERT (SELECT lease_token=job.lease_token FROM public.entitlement_reconciliation_jobs WHERE provider='stripe' AND subject='sub_scheduled');
  ASSERT public.finish_entitlement_reconciliation('stripe',job.subject,job.lease_token,true);
  ASSERT NOT EXISTS(SELECT 1 FROM public.claim_entitlement_reconciliation(ARRAY['stripe'],false));
  -- The webhook can now acquire the same resource and apply current cancellation.
  competing:=public.claim_stripe_event('evt_competing','customer.subscription.updated','subscription:sub_scheduled');
  ASSERT competing->>'state'='claimed';
  PERFORM public.finish_stripe_event('evt_competing',(competing->>'token')::uuid,d||'{"status":"canceled"}');
  ASSERT NOT (public.effective_premium_entitlement(u)->>'is_premium')::boolean;
  UPDATE public.entitlement_reconciliation_jobs SET next_attempt_at=t WHERE provider='stripe';
  ASSERT NOT EXISTS(SELECT 1 FROM public.claim_entitlement_reconciliation(ARRAY['stripe'],false));
  -- Recoverable statuses remain eligible; permanently expired subscriptions do not.
  UPDATE public.stripe_subscriptions SET status='past_due' WHERE subscription_id='sub_scheduled';
  SELECT * INTO job FROM public.claim_entitlement_reconciliation(ARRAY['stripe'],false);
  ASSERT job.subject='sub_scheduled';
  ASSERT public.finish_entitlement_reconciliation('stripe',job.subject,job.lease_token,false);
  UPDATE public.stripe_subscriptions SET status='incomplete_expired' WHERE subscription_id='sub_scheduled';
  UPDATE public.entitlement_reconciliation_jobs SET next_attempt_at=t WHERE provider='stripe';
  ASSERT NOT EXISTS(SELECT 1 FROM public.claim_entitlement_reconciliation(ARRAY['stripe'],false));
  UPDATE public.stripe_subscriptions SET status='active' WHERE subscription_id='sub_scheduled';
  SELECT * INTO job FROM public.claim_entitlement_reconciliation(ARRAY['stripe'],false);
  claim:=public.claim_stripe_event('reconcile_deleted','subscription.reconciliation','subscription:sub_scheduled');
  DELETE FROM auth.users WHERE id=u;
  ASSERT NOT EXISTS(SELECT 1 FROM public.entitlement_reconciliation_jobs WHERE provider='stripe');
  ASSERT NOT public.finish_entitlement_reconciliation('stripe',job.subject,job.lease_token,true);
  BEGIN
    PERFORM public.finish_stripe_event('reconcile_deleted',(claim->>'token')::uuid,d);
    RAISE EXCEPTION 'Deleted account regained coverage';
  EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM='Customer already bound'; END;
  ASSERT EXISTS(SELECT 1 FROM public.stripe_customers WHERE customer_id='cus_scheduled' AND user_id IS NULL);
  ASSERT NOT has_function_privilege('authenticated','public.claim_stripe_event(text,text,text)','EXECUTE');
  ASSERT NOT has_function_privilege('anon','public.finish_stripe_event(text,uuid,jsonb)','EXECUTE');
  ASSERT NOT has_table_privilege('authenticated','public.entitlement_reconciliation_jobs','SELECT');
END $$;
ROLLBACK;
\echo Stripe queue: seeding, migration reapplication, resource serialization, renewal, cancellation, terminal filtering and deletion passed.
