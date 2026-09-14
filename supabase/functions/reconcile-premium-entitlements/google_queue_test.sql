\ir queue_test.sql
\ir ../../migrations/20260912160000_google_token_reconciliation.sql
\ir ../../migrations/20260912160000_google_token_reconciliation.sql
BEGIN;
INSERT INTO auth.users VALUES('00000000-0000-4000-8000-000000000001'),('00000000-0000-4000-8000-000000000002');
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
DO $$
DECLARE u uuid:=auth.uid(); v uuid:='00000000-0000-4000-8000-000000000002'; t timestamptz:=now();
  k text:='production:'||repeat('a',64); replacement text:='production:'||repeat('b',64);
  sandbox text:='sandbox:'||repeat('c',64); m jsonb; s jsonb; job public.entitlement_reconciliation_jobs%ROWTYPE;
  env jsonb:='{"version":1,"keyId":"test","iv":"AAAAAAAAAAAAAAAA","ciphertext":"AAAAAAAAAAAAAAAAAAAAAAAA"}';
BEGIN
  m:=jsonb_build_object('subscriptionKey',k,'accountBound',true,'verifiedAt',t);
  -- Ciphertext failure rolls back the purchase, binding and entitlement together.
  BEGIN
    PERFORM public.fulfill_google_purchase_with_token(u,'google_play','token_first','statusxp_premium_monthly','subscription','SUBSCRIPTION_STATE_ACTIVE',t,t+interval '30 days',false,m,NULL);
    RAISE EXCEPTION 'Missing encryption accepted';
  EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM='Invalid encrypted token'; END;
  ASSERT NOT EXISTS(SELECT 1 FROM public.store_subscription_bindings WHERE subscription_key=k);
  ASSERT NOT EXISTS(SELECT 1 FROM public.store_purchase_events WHERE store_transaction_id='token_first');
  PERFORM public.fulfill_google_purchase_with_token(u,'google_play','token_first','statusxp_premium_monthly','subscription','SUBSCRIPTION_STATE_ACTIVE',t,t+interval '30 days',false,m,env);
  ASSERT (SELECT count(*)=1 FROM public.google_play_tokens);
  ASSERT (SELECT count(*)=1 FROM public.entitlement_reconciliation_jobs WHERE provider='google');
  UPDATE public.entitlement_reconciliation_jobs SET next_attempt_at=t+interval '4 hours' WHERE provider='google';
  -- A duplicate updates encryption without resetting its scheduled check.
  PERFORM public.fulfill_google_purchase_with_token(u,'google_play','token_first','statusxp_premium_monthly','subscription','SUBSCRIPTION_STATE_ACTIVE',t,t+interval '30 days',false,m,env||'{"keyId":"rotated"}');
  ASSERT (SELECT envelope->>'keyId'='rotated' FROM public.google_play_tokens WHERE subscription_key=k);
  ASSERT (SELECT next_attempt_at=t+interval '4 hours' FROM public.entitlement_reconciliation_jobs WHERE provider='google' AND subject=k);
  BEGIN
    PERFORM public.save_google_play_token(k,v,env);
    RAISE EXCEPTION 'Wrong owner accepted';
  EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM='Verified Google binding required'; END;
  BEGIN
    PERFORM public.save_google_play_token(k,u,env||'{"purchaseToken":"plaintext"}');
    RAISE EXCEPTION 'Plaintext field accepted';
  EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM='Invalid encrypted token'; END;
  s:=jsonb_build_object('subscriptionKey',k,'state','SUBSCRIPTION_STATE_ON_HOLD','expiresAt',t+interval '30 days');
  BEGIN
    PERFORM public.apply_google_notification_with_token('18001',repeat('a',64),t+interval '1 second',s,u,NULL);
    RAISE EXCEPTION 'Unencrypted notice committed';
  EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM='Invalid encrypted token'; END;
  ASSERT NOT EXISTS(SELECT 1 FROM public.google_play_notification_receipts WHERE message_id='18001');
  ASSERT (public.get_my_premium_entitlement()->>'is_premium')::boolean;
  PERFORM public.apply_google_notification_with_token('18001',repeat('a',64),t+interval '1 second',s,u,env);
  ASSERT NOT (public.get_my_premium_entitlement()->>'is_premium')::boolean;
  UPDATE public.entitlement_reconciliation_jobs SET next_attempt_at=t WHERE provider='google';
  SELECT * INTO job FROM public.claim_entitlement_reconciliation(ARRAY['google'],false);
  ASSERT job.subject=k;
  ASSERT NOT EXISTS(SELECT 1 FROM public.claim_entitlement_reconciliation(ARRAY['google'],false));
  ASSERT public.finish_entitlement_reconciliation('google',k,job.lease_token,true);
  -- Replacement retires the old token while creating a usable job for its successor.
  s:=jsonb_build_object('subscriptionKey',replacement,'linkedSubscriptionKey',k,'state','SUBSCRIPTION_STATE_ACTIVE','expiresAt',t+interval '30 days');
  PERFORM public.apply_google_notification_with_token('18002',repeat('b',64),t+interval '2 seconds',s,u,env);
  UPDATE public.entitlement_reconciliation_jobs SET next_attempt_at=t WHERE provider='google';
  SELECT * INTO job FROM public.claim_entitlement_reconciliation(ARRAY['google'],false);
  ASSERT job.subject=replacement;
  ASSERT NOT EXISTS(SELECT 1 FROM public.claim_entitlement_reconciliation(ARRAY['google'],false));
  ASSERT public.finish_entitlement_reconciliation('google',replacement,job.lease_token,true);
  -- Hash-only legacy bindings are never automatically queued.
  PERFORM public.bind_store_subscription(u,'google_play','production:'||repeat('d',64),NULL,true);
  ASSERT NOT EXISTS(SELECT 1 FROM public.entitlement_reconciliation_jobs WHERE subject='production:'||repeat('d',64));
  m:=jsonb_build_object('subscriptionKey',sandbox,'accountBound',true,'verifiedAt',t);
  PERFORM public.fulfill_google_purchase_with_token(u,'google_play','token_sandbox','statusxp_premium_monthly','subscription','SUBSCRIPTION_STATE_ACTIVE',t,t+interval '30 days',true,m,env);
  ASSERT NOT EXISTS(SELECT 1 FROM public.claim_entitlement_reconciliation(ARRAY['google'],false));
  SELECT * INTO job FROM public.claim_entitlement_reconciliation(ARRAY['google'],true);
  ASSERT job.subject=sandbox;
  DELETE FROM public.store_subscription_bindings WHERE subscription_key=sandbox;
  ASSERT NOT EXISTS(SELECT 1 FROM public.google_play_tokens WHERE subscription_key=sandbox);
  ASSERT NOT public.finish_entitlement_reconciliation('google',sandbox,job.lease_token,true);
  -- Long-expired terminal subscriptions no longer consume provider calls.
  UPDATE public.google_play_subscription_state SET store_state='SUBSCRIPTION_STATE_EXPIRED',expires_at=t-interval '61 days' WHERE subscription_key=replacement;
  UPDATE public.entitlement_reconciliation_jobs SET next_attempt_at=t WHERE provider='google';
  ASSERT NOT EXISTS(SELECT 1 FROM public.claim_entitlement_reconciliation(ARRAY['google'],true));
  UPDATE public.google_play_subscription_state SET expires_at=NULL WHERE subscription_key=replacement;
  SELECT * INTO job FROM public.claim_entitlement_reconciliation(ARRAY['google'],false);
  ASSERT job.subject=replacement; -- An unknown expiry cannot establish the 60-day cutoff.
  ASSERT public.finish_entitlement_reconciliation('google',replacement,job.lease_token,false);
  PERFORM public.apply_google_notification_with_token('18003',repeat('c',64),t,
    jsonb_build_object('subscriptionKey','production:'||repeat('f',64),'state','SUBSCRIPTION_STATE_EXPIRED','expiresAt',t),NULL,NULL);
  ASSERT NOT EXISTS(SELECT 1 FROM public.google_play_tokens WHERE subscription_key='production:'||repeat('f',64));
  ASSERT NOT has_table_privilege('authenticated','public.google_play_tokens','SELECT');
  ASSERT NOT has_table_privilege('anon','public.google_play_tokens','SELECT');
  ASSERT NOT has_table_privilege('service_role','public.google_play_tokens','INSERT');
  ASSERT NOT has_function_privilege('authenticated','public.apply_google_notification_with_token(text,text,timestamptz,jsonb,uuid,jsonb)','EXECUTE');
  ASSERT NOT has_function_privilege('authenticated','public.fulfill_google_purchase_with_token(uuid,text,text,text,text,text,timestamptz,timestamptz,boolean,jsonb,jsonb)','EXECUTE');
  ASSERT NOT has_function_privilege('service_role','public.save_google_play_token(text,uuid,jsonb)','EXECUTE');
  DELETE FROM auth.users WHERE id=u;
  ASSERT NOT EXISTS(SELECT 1 FROM public.google_play_tokens);
  ASSERT NOT EXISTS(SELECT 1 FROM public.entitlement_reconciliation_jobs WHERE provider='google');
  ASSERT EXISTS(SELECT 1 FROM public.store_subscription_bindings WHERE subscription_key=k AND user_id IS NULL);
END;
$$;
ROLLBACK;
