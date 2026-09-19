\ir ../verify-store-purchase/entitlement_test.sql
\ir ../../migrations/20260912130000_google_play_notifications.sql
\ir ../../migrations/20260912130000_google_play_notifications.sql
BEGIN;
INSERT INTO auth.users VALUES('00000000-0000-4000-8000-000000000001');
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
DO $$
DECLARE u uuid:=auth.uid(); t timestamptz:=now(); k text:='production:'||repeat('a',64); snapshot jsonb; m jsonb;
BEGIN
  m:=jsonb_build_object('subscriptionKey',k,'accountBound',true,'verifiedAt',t);
  PERFORM public.fulfill_verified_store_purchase(u,'google_play','play_first','statusxp_premium_monthly','subscription','SUBSCRIPTION_STATE_ACTIVE',t,t+interval '30 days',false,m);
  ASSERT (SELECT store_state='SUBSCRIPTION_STATE_ACTIVE' FROM public.google_play_subscription_state WHERE subscription_key=k);
  snapshot:=jsonb_build_object('subscriptionKey',k,'state','SUBSCRIPTION_STATE_ON_HOLD','expiresAt',t+interval '30 days');
  PERFORM public.apply_google_play_notification('1001',repeat('b',64),t+interval '2 seconds',snapshot,u);
  ASSERT NOT (public.get_my_premium_entitlement()->>'is_premium')::boolean;
  ASSERT public.can_use_ai(u)->>'source'='daily_free';
  PERFORM public.apply_google_play_notification('1001',repeat('b',64),t+interval '3 seconds',snapshot,u);
  ASSERT (SELECT count(*)=1 FROM public.google_play_notification_receipts);
  BEGIN
    PERFORM public.apply_google_play_notification('1001',repeat('c',64),t,snapshot,u);
    RAISE EXCEPTION 'Conflicting replay accepted';
  EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM='Message conflict'; END;
  -- An in-flight mobile verification must not restore coverage after a hold.
  PERFORM public.fulfill_verified_store_purchase(u,'google_play','play_second','statusxp_premium_monthly','subscription','SUBSCRIPTION_STATE_ACTIVE',t,t+interval '60 days',false,m||jsonb_build_object('verifiedAt',t+interval '1 second'));
  ASSERT NOT (public.get_my_premium_entitlement()->>'is_premium')::boolean;
  PERFORM public.apply_google_play_notification('1002',repeat('d',64),t+interval '1 second',snapshot||'{"state":"SUBSCRIPTION_STATE_ACTIVE"}'::jsonb,u);
  ASSERT NOT (public.get_my_premium_entitlement()->>'is_premium')::boolean;
  -- Current recovery and grace restore coverage; voluntary cancellation keeps expiry.
  PERFORM public.apply_google_play_notification('1003',repeat('e',64),t+interval '3 seconds',snapshot||'{"state":"SUBSCRIPTION_STATE_IN_GRACE_PERIOD"}'::jsonb,u);
  ASSERT (public.get_my_premium_entitlement()->>'is_premium')::boolean;
  PERFORM public.apply_google_play_notification('1004',repeat('f',64),t+interval '4 seconds',snapshot||'{"state":"SUBSCRIPTION_STATE_CANCELED"}'::jsonb,u);
  ASSERT (public.get_my_premium_entitlement()->>'is_premium')::boolean;
  -- Another provider survives Google expiry.
  INSERT INTO public.stripe_customers VALUES('cus_playfallback',u);
  INSERT INTO public.stripe_subscriptions VALUES('sub_playfallback','cus_playfallback','active',t+interval '15 days',t);
  PERFORM public.apply_google_play_notification('1005',repeat('a',64),t+interval '5 seconds',snapshot||jsonb_build_object('state','SUBSCRIPTION_STATE_EXPIRED','expiresAt',t),u);
  ASSERT public.get_my_premium_entitlement()->>'premium_source'='stripe';
  -- A fresh mobile recovery updates the same authoritative state.
  PERFORM public.fulfill_verified_store_purchase(u,'google_play','play_second','statusxp_premium_monthly','subscription','SUBSCRIPTION_STATE_ACTIVE',t,t+interval '60 days',false,m||jsonb_build_object('verifiedAt',t+interval '6 seconds'));
  ASSERT (SELECT store_state='SUBSCRIPTION_STATE_ACTIVE' FROM public.google_play_subscription_state WHERE subscription_key=k);
  -- Unknown ownership records state without granting anyone access.
  PERFORM public.apply_google_play_notification('1006',repeat('b',64),t,snapshot||jsonb_build_object('subscriptionKey','production:'||repeat('c',64),'state','SUBSCRIPTION_STATE_ACTIVE'),NULL);
  ASSERT (SELECT count(*)=1 FROM public.store_subscription_bindings WHERE platform='google_play');
  BEGIN
    PERFORM public.apply_google_play_notification('1007',repeat('c',64),t,snapshot||'{"state":"UNRECOGNIZED"}'::jsonb,u);
    RAISE EXCEPTION 'Unknown state accepted';
  EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM='Invalid Google state'; END;
  ASSERT NOT EXISTS(SELECT 1 FROM public.google_play_notification_receipts WHERE message_id='1007');
  -- A completed replacement permanently retires the old token's coverage.
  PERFORM public.apply_google_play_notification('1008',repeat('d',64),t+interval '7 seconds',
    snapshot||jsonb_build_object('subscriptionKey','production:'||repeat('d',64),'linkedSubscriptionKey',k,'state','SUBSCRIPTION_STATE_ACTIVE'),u);
  ASSERT (SELECT superseded FROM public.google_play_subscription_state WHERE subscription_key=k);
  PERFORM public.apply_google_play_notification('1009',repeat('e',64),t+interval '8 seconds',
    snapshot||jsonb_build_object('subscriptionKey','production:'||repeat('d',64),'state','SUBSCRIPTION_STATE_EXPIRED','expiresAt',t),u);
  PERFORM public.apply_google_play_notification('1010',repeat('f',64),t+interval '9 seconds',snapshot||'{"state":"SUBSCRIPTION_STATE_ACTIVE"}'::jsonb,u);
  UPDATE public.stripe_subscriptions SET status='canceled';
  ASSERT NOT (public.get_my_premium_entitlement()->>'is_premium')::boolean;
  ASSERT NOT has_function_privilege('authenticated','public.apply_google_play_notification(text,text,timestamptz,jsonb,uuid)','EXECUTE');
  ASSERT NOT has_table_privilege('authenticated','public.google_play_subscription_state','UPDATE');
END $$;
ROLLBACK;
\echo Google notifications: receipt atomicity, replay, hold, recovery, grace, cancellation, expiry, fallback, mobile ordering and ownership checks passed.
