DO $$ BEGIN IF current_database()<>'statusxp_stripe_test' THEN RAISE EXCEPTION 'Isolated test database required'; END IF; END $$;
CREATE SCHEMA auth;
CREATE TABLE auth.users(id uuid PRIMARY KEY);
CREATE TABLE public.user_ai_credits(user_id uuid PRIMARY KEY,pack_credits integer,updated_at timestamptz);
CREATE TABLE public.user_ai_pack_purchases(user_id uuid,pack_type text,credits_purchased integer,price_paid numeric,platform text);
CREATE TABLE public.user_premium_status(user_id uuid PRIMARY KEY,is_premium boolean,premium_source text,premium_since timestamptz,premium_expires_at timestamptz,updated_at timestamptz);
\ir ../../migrations/20260911200000_stripe_fulfillment.sql
\ir ../../migrations/20260911200000_stripe_fulfillment.sql
BEGIN;
DO $$
DECLARE u uuid:='00000000-0000-4000-8000-000000000001'; v uuid:='00000000-0000-4000-8000-000000000002';
  c jsonb; payload jsonb;
BEGIN
  INSERT INTO auth.users VALUES(u),(v);
  PERFORM public.bind_stripe_customer(u,'cus_test');
  BEGIN PERFORM public.bind_stripe_customer(v,'cus_test'); RAISE EXCEPTION 'Binding incorrectly allowed';
    EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM='Customer already bound'; END;
  c:=public.claim_stripe_event('evt_pack1','checkout.session.completed','checkout:cs_test');
  ASSERT c->>'state'='claimed';
  ASSERT public.claim_stripe_event('evt_pack2','checkout.session.async_payment_succeeded','checkout:cs_test')->>'state'='busy';
  payload:=jsonb_build_object('kind','pack','user_id',u,'customer_id','cus_test','session_id','cs_test','payment_intent','pi_test','pack_type','small','amount',199,'currency','usd');
  PERFORM public.finish_stripe_event('evt_pack1',(c->>'token')::uuid,payload);
  ASSERT public.claim_stripe_event('evt_pack1','checkout.session.completed','checkout:cs_test')->>'state'='done';
  c:=public.claim_stripe_event('evt_pack2','checkout.session.async_payment_succeeded','checkout:cs_test');
  PERFORM public.finish_stripe_event('evt_pack2',(c->>'token')::uuid,payload);
  ASSERT (SELECT pack_credits=20 FROM public.user_ai_credits WHERE user_id=u);
  ASSERT (SELECT count(*)=1 FROM public.user_ai_pack_purchases);
  -- Invalid pricing rolls back balance, purchase, and event completion together.
  c:=public.claim_stripe_event('evt_badprice','checkout.session.completed','checkout:cs_badprice');
  BEGIN
    PERFORM public.finish_stripe_event('evt_badprice',(c->>'token')::uuid,
      payload || '{"session_id":"cs_badprice","payment_intent":"pi_badprice","amount":1}'::jsonb);
    RAISE EXCEPTION 'Invalid price accepted';
  EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM='Invalid paid pack'; END;
  ASSERT (SELECT state='pending' FROM public.stripe_webhook_events WHERE event_id='evt_badprice');
  ASSERT (SELECT pack_credits=20 FROM public.user_ai_credits WHERE user_id=u);
  -- New subscription state applies without overwriting another active source.
  INSERT INTO public.user_premium_status VALUES(u,true,'apple',now(),now()+interval '2 days',now());
  payload:=jsonb_build_object('kind','subscription','user_id',u,'customer_id','cus_test','subscription_id','sub_test','status','active','expires_at',now()+interval '30 days');
  c:=public.claim_stripe_event('evt_sub1','customer.subscription.updated','subscription:sub_test');
  PERFORM public.finish_stripe_event('evt_sub1',(c->>'token')::uuid,payload);
  ASSERT (SELECT premium_source='apple' AND is_premium FROM public.user_premium_status WHERE user_id=u);
  payload:=payload || '{"status":"canceled"}'::jsonb;
  c:=public.claim_stripe_event('evt_sub2','customer.subscription.deleted','subscription:sub_test');
  PERFORM public.finish_stripe_event('evt_sub2',(c->>'token')::uuid,payload);
  ASSERT (SELECT premium_source='apple' AND is_premium FROM public.user_premium_status WHERE user_id=u);
  -- Multiple Stripe subscriptions: cancellation must leave another active one.
  UPDATE public.user_premium_status SET premium_source='stripe';
  payload:=payload || '{"status":"active","subscription_id":"sub_other"}'::jsonb;
  c:=public.claim_stripe_event('evt_other','customer.subscription.updated','subscription:sub_other');
  PERFORM public.finish_stripe_event('evt_other',(c->>'token')::uuid,payload);
  payload:=payload || '{"status":"canceled","subscription_id":"sub_test"}'::jsonb;
  c:=public.claim_stripe_event('evt_sub3','customer.subscription.deleted','subscription:sub_test');
  PERFORM public.finish_stripe_event('evt_sub3',(c->>'token')::uuid,payload);
  ASSERT (SELECT is_premium FROM public.user_premium_status WHERE user_id=u);
  -- Expired lease cannot commit even if provider work completes late.
  c:=public.claim_stripe_event('evt_late','customer.subscription.updated','subscription:sub_test');
  UPDATE public.stripe_resource_leases SET expires_at=now()-interval '1 second' WHERE resource='subscription:sub_test';
  BEGIN PERFORM public.finish_stripe_event('evt_late',(c->>'token')::uuid,payload); RAISE EXCEPTION 'Late commit accepted';
    EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM='Lease expired'; END;
  ASSERT public.claim_stripe_event('evt_late','customer.subscription.updated','subscription:sub_test')->>'state'='claimed';
  ASSERT NOT has_function_privilege('authenticated','public.finish_stripe_event(text,uuid,jsonb)','execute');
  ASSERT NOT has_table_privilege('anon','public.stripe_customers','select');
  DELETE FROM auth.users WHERE id=u;
  ASSERT (SELECT user_id IS NULL FROM public.stripe_customers WHERE customer_id='cus_test');
END;
$$;
ROLLBACK;
