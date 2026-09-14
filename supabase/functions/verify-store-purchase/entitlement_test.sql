\ir ../twitch-eventsub-webhook/binding_test.sql
\ir ../../migrations/20260727130000_secure_store_entitlements.sql
\ir ../../migrations/20260912120000_store_subscription_bindings.sql
\ir ../../migrations/20260912120000_store_subscription_bindings.sql
BEGIN;
INSERT INTO auth.users VALUES('00000000-0000-4000-8000-000000000001'),('00000000-0000-4000-8000-000000000002');
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
DO $$
DECLARE u uuid:=auth.uid(); v uuid:='00000000-0000-4000-8000-000000000002'; t timestamptz:=now();
  m jsonb:=jsonb_build_object('subscriptionKey','production:10001','accountBound',true,'verifiedAt',now()); r jsonb;
BEGIN
  BEGIN
    PERFORM public.fulfill_verified_store_purchase(u,'app_store','apple_0001','statusxp_premium_monthly','subscription','ACTIVE',t,t+interval '30 days',false,m||'{"accountBound":false}'::jsonb);
    RAISE EXCEPTION 'Unproven ownership accepted';
  EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM='Subscription ownership needs verification'; END;
  ASSERT (SELECT count(*)=0 FROM public.store_subscription_bindings);
  PERFORM public.fulfill_verified_store_purchase(u,'app_store','apple_0001','statusxp_premium_monthly','subscription','ACTIVE',t,t+interval '30 days',false,m);
  ASSERT public.get_my_premium_entitlement()->>'premium_source'='apple';
  ASSERT public.can_use_ai(u)->>'source'='premium';
  BEGIN
    PERFORM public.fulfill_verified_store_purchase(v,'app_store','apple_0002','statusxp_premium_monthly','subscription','ACTIVE',t,t+interval '60 days',false,m);
    RAISE EXCEPTION 'Renewal moved accounts';
  EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM='Subscription belongs to another account'; END;
  -- Already-bound legacy renewals may lack an account claim, but not change owner.
  PERFORM public.fulfill_verified_store_purchase(u,'app_store','apple_0002','statusxp_premium_monthly','subscription','ACTIVE',t,t+interval '60 days',false,m||'{"accountBound":false}'::jsonb);
  ASSERT (public.get_my_premium_entitlement()->>'premium_expires_at')::timestamptz=t+interval '60 days';
  r:=public.fulfill_verified_store_purchase(u,'app_store','apple_0001','statusxp_premium_monthly','subscription','ACTIVE',t,t+interval '20 days',false,m||jsonb_build_object('verifiedAt',t+interval '2 seconds'));
  ASSERT (r->>'already_processed')::boolean;
  ASSERT (public.get_my_premium_entitlement()->>'premium_expires_at')::timestamptz=t+interval '60 days';
  PERFORM public.fulfill_verified_store_purchase(u,'app_store','apple_0001','statusxp_premium_monthly','subscription','ACTIVE',t,t+interval '90 days',false,m||jsonb_build_object('verifiedAt',t+interval '1 second'));
  ASSERT (SELECT expires_at=t+interval '20 days' FROM public.store_purchase_events WHERE store_transaction_id='apple_0001');
  -- Effective access reads period state; a stale projection cannot resurrect it.
  UPDATE public.store_purchase_events SET store_state='REVOKED' WHERE platform='app_store';
  ASSERT NOT (public.get_my_premium_entitlement()->>'is_premium')::boolean;
  m:=jsonb_build_object('subscriptionKey','production:aaa111','accountBound',true,'verifiedAt',t);
  PERFORM public.fulfill_verified_store_purchase(u,'google_play','google_001','statusxp_premium_monthly','subscription','SUBSCRIPTION_STATE_CANCELED',t,t+interval '10 days',false,m);
  ASSERT public.get_my_premium_entitlement()->>'premium_source'='google';
  -- Replacement binds both tokens to the same owner, including future renewals.
  m:=m||'{"subscriptionKey":"production:bbb222","linkedSubscriptionKey":"production:aaa111","accountBound":false}'::jsonb;
  PERFORM public.fulfill_verified_store_purchase(u,'google_play','google_002','statusxp_premium_monthly','subscription','SUBSCRIPTION_STATE_IN_GRACE_PERIOD',t,t+interval '20 days',false,m);
  BEGIN
    PERFORM public.fulfill_verified_store_purchase(v,'google_play','google_003','statusxp_premium_monthly','subscription','SUBSCRIPTION_STATE_ACTIVE',t,t+interval '40 days',false,m||'{"accountBound":true}'::jsonb);
    RAISE EXCEPTION 'Replacement moved accounts';
  EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM='Subscription belongs to another account'; END;
  BEGIN
    PERFORM public.fulfill_verified_store_purchase(u,'google_play','google_004','statusxp_premium_monthly','subscription','SUBSCRIPTION_STATE_ACTIVE',t,NULL,false,m);
    RAISE EXCEPTION 'Missing expiry accepted';
  EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM='Invalid active subscription'; END;
  UPDATE public.store_purchase_events SET expires_at=now();
  ASSERT NOT (public.get_my_premium_entitlement()->>'is_premium')::boolean;
  PERFORM public.fulfill_verified_store_purchase(u,'app_store','pack_00001','statusxp_ai_pack_small','consumable','PURCHASED');
  PERFORM public.fulfill_verified_store_purchase(u,'app_store','pack_00001','statusxp_ai_pack_small','consumable','PURCHASED');
  ASSERT (SELECT pack_credits=20 FROM public.user_ai_credits WHERE user_id=u);
  ASSERT (SELECT count(*)=1 FROM public.user_ai_pack_purchases WHERE user_id=u);
  ASSERT NOT has_table_privilege('authenticated','public.store_subscription_bindings','SELECT');
  ASSERT NOT has_function_privilege('authenticated','public.fulfill_verified_store_purchase(uuid,text,text,text,text,text,timestamptz,timestamptz,boolean,jsonb)','EXECUTE');
  -- Account deletion leaves a binding tombstone that cannot be claimed again.
  DELETE FROM auth.users WHERE id=u;
  BEGIN
    PERFORM public.fulfill_verified_store_purchase(v,'app_store','apple_0003','statusxp_premium_monthly','subscription','ACTIVE',t,t+interval '60 days',false,
      jsonb_build_object('subscriptionKey','production:10001','accountBound',true,'verifiedAt',t));
    RAISE EXCEPTION 'Deleted ownership reassigned';
  EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM='Subscription belongs to another account'; END;
END $$;
ROLLBACK;
\echo Store ownership, renewals, restore ordering, replacement tokens, effective access and consumable replay checks passed.
