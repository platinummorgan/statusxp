BEGIN;
CREATE TABLE IF NOT EXISTS public.stripe_customers (
  customer_id text PRIMARY KEY,
  user_id uuid UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL
);
CREATE TABLE IF NOT EXISTS public.stripe_webhook_events (
  event_id text PRIMARY KEY, event_type text NOT NULL, resource text NOT NULL,
  state text NOT NULL DEFAULT 'pending' CHECK(state IN ('pending','done')),
  received_at timestamptz NOT NULL DEFAULT now(), completed_at timestamptz
);
CREATE TABLE IF NOT EXISTS public.stripe_resource_leases (
  resource text PRIMARY KEY, token uuid NOT NULL, expires_at timestamptz NOT NULL
);
CREATE TABLE IF NOT EXISTS public.stripe_pack_fulfillments (
  session_id text PRIMARY KEY, payment_intent text UNIQUE NOT NULL,
  customer_id text NOT NULL REFERENCES public.stripe_customers(customer_id),
  pack_type text NOT NULL, credits integer NOT NULL, fulfilled_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.stripe_subscriptions (
  subscription_id text PRIMARY KEY,
  customer_id text NOT NULL REFERENCES public.stripe_customers(customer_id),
  status text NOT NULL, expires_at timestamptz NOT NULL, updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.stripe_customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stripe_webhook_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stripe_resource_leases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stripe_pack_fulfillments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stripe_subscriptions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.stripe_customers, public.stripe_webhook_events, public.stripe_resource_leases,
  public.stripe_pack_fulfillments, public.stripe_subscriptions FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.stripe_customers, public.stripe_webhook_events, public.stripe_resource_leases,
  public.stripe_pack_fulfillments, public.stripe_subscriptions TO service_role;

CREATE OR REPLACE FUNCTION public.bind_stripe_customer(p_user_id uuid,p_customer_id text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE owner_id uuid;
BEGIN
  IF p_user_id IS NULL OR p_customer_id !~ '^cus_[A-Za-z0-9]+$' THEN RAISE EXCEPTION 'Invalid binding'; END IF;
  INSERT INTO public.stripe_customers(customer_id,user_id) VALUES(p_customer_id,p_user_id)
    ON CONFLICT(customer_id) DO NOTHING;
  SELECT user_id INTO owner_id FROM public.stripe_customers WHERE customer_id=p_customer_id;
  IF owner_id IS DISTINCT FROM p_user_id THEN RAISE EXCEPTION 'Customer already bound'; END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.claim_stripe_event(p_event_id text,p_event_type text,p_resource text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE e public.stripe_webhook_events%ROWTYPE; v_token uuid := gen_random_uuid(); v_claim uuid;
BEGIN
  INSERT INTO public.stripe_webhook_events(event_id,event_type,resource) VALUES(p_event_id,p_event_type,p_resource)
    ON CONFLICT DO NOTHING;
  SELECT * INTO e FROM public.stripe_webhook_events WHERE event_id=p_event_id FOR UPDATE;
  IF e.resource<>p_resource OR e.event_type<>p_event_type THEN RAISE EXCEPTION 'Event conflict'; END IF;
  IF e.state='done' THEN RETURN jsonb_build_object('state','done'); END IF;
  INSERT INTO public.stripe_resource_leases(resource,token,expires_at)
    VALUES(p_resource,v_token,clock_timestamp()+interval '2 minutes')
    ON CONFLICT(resource) DO UPDATE SET token=EXCLUDED.token,expires_at=EXCLUDED.expires_at
      WHERE public.stripe_resource_leases.expires_at<=clock_timestamp()
    RETURNING token INTO v_claim;
  RETURN jsonb_build_object('state',CASE WHEN v_claim IS NULL THEN 'busy' ELSE 'claimed' END,'token',v_claim);
END;
$$;

CREATE OR REPLACE FUNCTION public.finish_stripe_event(p_event_id text,p_token uuid,p_data jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE e public.stripe_webhook_events%ROWTYPE; v_user uuid; v_customer text := p_data->>'customer_id';
  v_credits integer; v_amount integer; v_inserted text; v_expiry timestamptz; v_source text;
BEGIN
  SELECT * INTO e FROM public.stripe_webhook_events WHERE event_id=p_event_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Unknown event'; END IF;
  IF e.state='done' THEN RETURN; END IF;
  PERFORM 1 FROM public.stripe_resource_leases WHERE resource=e.resource AND token=p_token
    AND expires_at>clock_timestamp() FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Lease expired'; END IF;
  IF p_data->>'kind' IN ('pack','subscription') THEN
    IF p_data->>'user_id' IS NOT NULL THEN
      PERFORM public.bind_stripe_customer((p_data->>'user_id')::uuid,v_customer);
    END IF;
    SELECT user_id INTO v_user FROM public.stripe_customers WHERE customer_id=v_customer;
    IF v_user IS NULL THEN RAISE EXCEPTION 'Unmapped or deleted customer'; END IF;
    -- Serialize balance and effective entitlement updates across subscriptions.
    PERFORM 1 FROM auth.users WHERE id=v_user FOR UPDATE;
    IF p_data->>'kind'='pack' THEN
      IF e.resource <> 'checkout:' || (p_data->>'session_id') THEN RAISE EXCEPTION 'Resource mismatch'; END IF;
      SELECT credits,cents INTO v_credits,v_amount FROM (VALUES
        ('small',20,199),('medium',60,499),('large',150,999)
      ) AS packs(kind,credits,cents) WHERE kind=p_data->>'pack_type';
      IF v_credits IS NULL OR (p_data->>'currency') IS DISTINCT FROM 'usd' OR (p_data->>'amount')::integer IS DISTINCT FROM v_amount
        OR coalesce(p_data->>'payment_intent','') !~ '^pi_[A-Za-z0-9]+$' THEN RAISE EXCEPTION 'Invalid paid pack'; END IF;
      INSERT INTO public.stripe_pack_fulfillments(session_id,payment_intent,customer_id,pack_type,credits)
        VALUES(p_data->>'session_id',p_data->>'payment_intent',v_customer,p_data->>'pack_type',v_credits)
        ON CONFLICT DO NOTHING RETURNING session_id INTO v_inserted;
      IF v_inserted IS NOT NULL THEN
        INSERT INTO public.user_ai_credits(user_id,pack_credits) VALUES(v_user,v_credits)
          ON CONFLICT(user_id) DO UPDATE SET pack_credits=coalesce(public.user_ai_credits.pack_credits,0)+v_credits,updated_at=now();
        INSERT INTO public.user_ai_pack_purchases(user_id,pack_type,credits_purchased,price_paid,platform)
          VALUES(v_user,p_data->>'pack_type',v_credits,v_amount/100.0,'web');
      ELSIF NOT EXISTS(SELECT 1 FROM public.stripe_pack_fulfillments WHERE session_id=p_data->>'session_id'
        AND payment_intent=p_data->>'payment_intent' AND customer_id=v_customer AND pack_type=p_data->>'pack_type') THEN
        RAISE EXCEPTION 'Fulfillment conflict';
      END IF;
    ELSE
      IF e.resource <> 'subscription:' || (p_data->>'subscription_id') THEN RAISE EXCEPTION 'Resource mismatch'; END IF;
      INSERT INTO public.stripe_subscriptions(subscription_id,customer_id,status,expires_at)
        VALUES(p_data->>'subscription_id',v_customer,p_data->>'status',(p_data->>'expires_at')::timestamptz)
        ON CONFLICT(subscription_id) DO UPDATE SET status=EXCLUDED.status,expires_at=EXCLUDED.expires_at,updated_at=now()
          WHERE public.stripe_subscriptions.customer_id=EXCLUDED.customer_id;
      IF NOT FOUND THEN RAISE EXCEPTION 'Subscription binding conflict'; END IF;
      SELECT max(expires_at) INTO v_expiry FROM public.stripe_subscriptions
        WHERE customer_id=v_customer AND status='active' AND expires_at>now();
      INSERT INTO public.user_premium_status(user_id,is_premium,premium_source,premium_since,premium_expires_at,updated_at)
        VALUES(v_user,v_expiry IS NOT NULL,'stripe',now(),coalesce(v_expiry,now()),now())
        ON CONFLICT(user_id) DO UPDATE SET is_premium=EXCLUDED.is_premium,premium_source='stripe',
          premium_expires_at=EXCLUDED.premium_expires_at,updated_at=now()
        WHERE public.user_premium_status.premium_source='stripe'
          OR NOT coalesce(public.user_premium_status.is_premium,false)
          OR public.user_premium_status.premium_expires_at<=now();
    END IF;
  ELSIF p_data->>'kind' IS DISTINCT FROM 'ignored' THEN RAISE EXCEPTION 'Unknown fulfillment'; END IF;
  UPDATE public.stripe_webhook_events SET state='done',completed_at=now() WHERE event_id=p_event_id;
  DELETE FROM public.stripe_resource_leases WHERE resource=e.resource AND token=p_token;
END;
$$;
REVOKE ALL ON FUNCTION public.bind_stripe_customer(uuid,text),public.claim_stripe_event(text,text,text),public.finish_stripe_event(text,uuid,jsonb)
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.bind_stripe_customer(uuid,text),public.claim_stripe_event(text,text,text),public.finish_stripe_event(text,uuid,jsonb)
  TO service_role;
COMMIT;
