\ir ../google-play-notifications/entitlement_test.sql
\ir ../../migrations/20260912140000_apple_notifications.sql
\ir ../../migrations/20260912140000_apple_notifications.sql
BEGIN;
INSERT INTO auth.users VALUES('00000000-0000-4000-8000-000000000001');
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
DO $$
DECLARE u uuid:=auth.uid(); t timestamptz:=now(); k text:='production:10001'; s jsonb; m jsonb;
  message uuid:='00000000-0000-4000-8000-000000000010';
BEGIN
  m:=jsonb_build_object('subscriptionKey',k,'accountBound',true,'verifiedAt',t,'appleStatus',1);
  PERFORM public.fulfill_verified_store_purchase(u,'app_store','apple_first','statusxp_premium_monthly','subscription','ACTIVE',t,t+interval '30 days',false,m);
  ASSERT (SELECT status=1 FROM public.apple_subscription_state WHERE subscription_key=k);
  s:=jsonb_build_object('subscriptionKey',k,'status',5,'expiresAt',t+interval '30 days');
  PERFORM public.apply_apple_notification(message,repeat('a',64),t+interval '2 seconds',s,u);
  ASSERT NOT (public.get_my_premium_entitlement()->>'is_premium')::boolean;
  ASSERT public.can_use_ai(u)->>'source'='daily_free';
  PERFORM public.apply_apple_notification(message,repeat('a',64),t+interval '3 seconds',s,u);
  ASSERT (SELECT count(*)=1 FROM public.apple_notification_receipts);
  BEGIN
    PERFORM public.apply_apple_notification(message,repeat('b',64),t,s,u);
    RAISE EXCEPTION 'Receipt conflict accepted';
  EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM='Message conflict'; END;
  PERFORM public.fulfill_verified_store_purchase(u,'app_store','apple_later','statusxp_premium_monthly','subscription','ACTIVE',t,t+interval '60 days',false,m||jsonb_build_object('verifiedAt',t+interval '1 second'));
  ASSERT NOT (public.get_my_premium_entitlement()->>'is_premium')::boolean;
  -- Current recovery and grace from mobile verification update status metadata.
  PERFORM public.fulfill_verified_store_purchase(u,'app_store','apple_later','statusxp_premium_monthly','subscription','ACTIVE',t,t+interval '3 days',false,m||jsonb_build_object('verifiedAt',t+interval '3 seconds','appleStatus',4));
  ASSERT (SELECT status=4 FROM public.apple_subscription_state WHERE subscription_key=k);
  ASSERT (public.get_my_premium_entitlement()->>'premium_expires_at')::timestamptz=t+interval '3 days';
  -- Billing retry outside grace does not grant premium despite a stale future expiry.
  PERFORM public.apply_apple_notification('00000000-0000-4000-8000-000000000011',repeat('b',64),t+interval '4 seconds',s||'{"status":3}'::jsonb,u);
  ASSERT NOT (public.get_my_premium_entitlement()->>'is_premium')::boolean;
  INSERT INTO public.stripe_customers VALUES('cus_applefallback',u);
  INSERT INTO public.stripe_subscriptions VALUES('sub_applefallback','cus_applefallback','active',t+interval '15 days',t);
  PERFORM public.apply_apple_notification('00000000-0000-4000-8000-000000000012',repeat('c',64),t+interval '5 seconds',s||jsonb_build_object('status',2,'expiresAt',t),u);
  ASSERT public.get_my_premium_entitlement()->>'premium_source'='stripe';
  BEGIN
    PERFORM public.apply_apple_notification('00000000-0000-4000-8000-000000000013',repeat('d',64),t,s||'{"status":9}'::jsonb,u);
    RAISE EXCEPTION 'Unknown status accepted';
  EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM='Invalid Apple state'; END;
  ASSERT NOT EXISTS(SELECT 1 FROM public.apple_notification_receipts WHERE message_id='00000000-0000-4000-8000-000000000013');
  PERFORM public.apply_apple_notification('00000000-0000-4000-8000-000000000014',repeat('e',64),t,s||'{"subscriptionKey":"production:20002","status":1}'::jsonb,NULL);
  ASSERT (SELECT count(*)=1 FROM public.store_subscription_bindings WHERE platform='app_store');
  ASSERT NOT has_function_privilege('authenticated','public.apply_apple_notification(uuid,text,timestamptz,jsonb,uuid)','EXECUTE');
  ASSERT NOT has_table_privilege('authenticated','public.apple_subscription_state','UPDATE');
END $$;
ROLLBACK;
\echo Apple notifications: receipt atomicity, revocation, grace, recovery, retry, expiry, fallback, ownership and mobile ordering passed.
