-- Billing-only rollout for the existing production store-verification schema.
-- Consolidates the already-tested provider state without changing AI guide or
-- sync quota APIs. Source migrations are identified below for review.
BEGIN;


-- Source: 20260911200000_stripe_fulfillment.sql
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

-- Source: 20260912100000_effective_premium.sql
CREATE INDEX IF NOT EXISTS stripe_subscriptions_customer_idx
  ON public.stripe_subscriptions(customer_id);

-- Read-time Stripe fallback: no scheduled job is needed at an expiry boundary.
-- Apple/Google and legacy Twitch still use their existing projection until
-- their durable, user-bound lifecycle records are available.
CREATE OR REPLACE FUNCTION public.effective_premium_entitlement(p_user_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  WITH candidates AS (
    SELECT p.premium_source, p.premium_since, p.premium_expires_at, 0 AS priority
    FROM public.user_premium_status p
    WHERE p.user_id = p_user_id AND p.is_premium
      AND (p.premium_expires_at IS NULL OR p.premium_expires_at > now())
      -- Once Stripe has authoritative records, a stale legacy flag must not
      -- resurrect a canceled subscription.
      AND (p.premium_source IS DISTINCT FROM 'stripe' OR NOT EXISTS (
        SELECT 1 FROM public.stripe_customers c
        JOIN public.stripe_subscriptions s ON s.customer_id = c.customer_id
        WHERE c.user_id = p.user_id
      ))
    UNION ALL
    SELECT 'stripe', NULL::timestamptz, s.expires_at, 1
    FROM public.stripe_customers c
    JOIN public.stripe_subscriptions s ON s.customer_id = c.customer_id
    WHERE c.user_id = p_user_id AND s.status = 'active' AND s.expires_at > now()
  )
  SELECT coalesce((
    SELECT jsonb_build_object('is_premium', true,
      'premium_source', premium_source, 'premium_since', premium_since,
      'premium_expires_at', premium_expires_at)
    FROM candidates
    ORDER BY priority, premium_expires_at DESC NULLS FIRST
    LIMIT 1
  ), jsonb_build_object('is_premium', false, 'premium_source', NULL,
    'premium_since', NULL, 'premium_expires_at', NULL));
$$;
REVOKE ALL ON FUNCTION public.effective_premium_entitlement(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.effective_premium_entitlement(uuid) TO service_role;
CREATE OR REPLACE FUNCTION public.get_my_premium_entitlement()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT public.effective_premium_entitlement(auth.uid());
$$;
REVOKE ALL ON FUNCTION public.get_my_premium_entitlement() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_premium_entitlement() TO authenticated;


-- Source: 20260912090000_twitch_event_receipts.sql
CREATE TABLE IF NOT EXISTS public.twitch_event_receipts (
  message_id text PRIMARY KEY, body_hash text NOT NULL, signed_at timestamptz NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.twitch_entitlement_state (
  twitch_user_id text PRIMARY KEY, observed_at timestamptz NOT NULL,
  active boolean NOT NULL, expires_at timestamptz NOT NULL
);
ALTER TABLE public.twitch_event_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.twitch_entitlement_state ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.twitch_event_receipts,public.twitch_entitlement_state FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.twitch_event_receipts,public.twitch_entitlement_state TO service_role;
CREATE OR REPLACE FUNCTION public.apply_twitch_event(
  p_message_id text,p_body_hash text,p_signed_at timestamptz,
  p_twitch_user_id text DEFAULT NULL,p_active boolean DEFAULT NULL
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_inserted text; v_old public.twitch_entitlement_state%ROWTYPE; v_user uuid; v_expiry timestamptz;
BEGIN
  INSERT INTO public.twitch_event_receipts(message_id,body_hash,signed_at)
    VALUES(p_message_id,p_body_hash,p_signed_at) ON CONFLICT DO NOTHING RETURNING message_id INTO v_inserted;
  IF v_inserted IS NULL THEN
    IF NOT EXISTS(SELECT 1 FROM public.twitch_event_receipts WHERE message_id=p_message_id AND body_hash=p_body_hash AND signed_at=p_signed_at) THEN
      RAISE EXCEPTION 'Message conflict';
    END IF;
    RETURN;
  END IF;
  IF p_twitch_user_id IS NULL OR p_active IS NULL THEN RETURN; END IF;
  -- Lock even the first observation for this Twitch account.
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('twitch:'||p_twitch_user_id,0));
  SELECT * INTO v_old FROM public.twitch_entitlement_state WHERE twitch_user_id=p_twitch_user_id;
  -- Equal-time inactive observations win; old deliveries cannot reactivate access.
  IF FOUND AND (v_old.observed_at>p_signed_at OR (v_old.observed_at=p_signed_at AND NOT v_old.active)) THEN RETURN; END IF;
  IF (SELECT count(*) FROM public.profiles WHERE twitch_user_id=p_twitch_user_id)>1 THEN RAISE EXCEPTION 'Ambiguous Twitch binding'; END IF;
  SELECT id INTO v_user FROM public.profiles WHERE twitch_user_id=p_twitch_user_id;
  IF v_user IS NOT NULL THEN PERFORM 1 FROM auth.users WHERE id=v_user FOR UPDATE; END IF;
  v_expiry:=CASE WHEN p_active THEN p_signed_at+interval '33 days'
    ELSE least(coalesce(v_old.expires_at,(SELECT premium_expires_at FROM public.user_premium_status WHERE user_id=v_user AND premium_source='twitch' AND is_premium),p_signed_at),p_signed_at+interval '3 days') END;
  INSERT INTO public.twitch_entitlement_state VALUES(p_twitch_user_id,p_signed_at,p_active,v_expiry)
    ON CONFLICT(twitch_user_id) DO UPDATE SET observed_at=EXCLUDED.observed_at,active=EXCLUDED.active,expires_at=EXCLUDED.expires_at;
  IF v_user IS NULL THEN RETURN; END IF;
  INSERT INTO public.user_premium_status(user_id,is_premium,premium_source,premium_expires_at,updated_at)
    VALUES(v_user,v_expiry>now(),'twitch',v_expiry,now())
    ON CONFLICT(user_id) DO UPDATE SET is_premium=EXCLUDED.is_premium,premium_source='twitch',premium_expires_at=EXCLUDED.premium_expires_at,updated_at=now()
      WHERE public.user_premium_status.premium_source='twitch'
        OR NOT coalesce(public.user_premium_status.is_premium,false)
        OR public.user_premium_status.premium_expires_at<=now();
END;
$$;
REVOKE ALL ON FUNCTION public.apply_twitch_event(text,text,timestamptz,text,boolean) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.apply_twitch_event(text,text,timestamptz,text,boolean) TO service_role;

-- Source: 20260912110000_twitch_account_bindings.sql
-- Only the OAuth callback may establish ownership. Do not backfill from
-- historically client-editable profile fields without verifying ownership.
CREATE TABLE IF NOT EXISTS public.twitch_account_bindings (
  twitch_user_id text PRIMARY KEY CHECK (twitch_user_id ~ '^[0-9]+$'),
  user_id uuid NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  linked_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.twitch_account_bindings ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.twitch_account_bindings FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.twitch_account_bindings TO service_role;

CREATE OR REPLACE FUNCTION public.bind_verified_twitch_account(p_user_id uuid,p_twitch_user_id text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE owner_id uuid;
BEGIN
  IF p_twitch_user_id IS NULL OR p_twitch_user_id !~ '^[0-9]+$' THEN RAISE EXCEPTION 'Invalid Twitch account'; END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('twitch:'||p_twitch_user_id,0));
  PERFORM 1 FROM auth.users WHERE id=p_user_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Unknown user'; END IF;
  INSERT INTO public.twitch_account_bindings(twitch_user_id,user_id)
    VALUES(p_twitch_user_id,p_user_id) ON CONFLICT(twitch_user_id) DO NOTHING;
  SELECT user_id INTO owner_id FROM public.twitch_account_bindings WHERE twitch_user_id=p_twitch_user_id;
  IF owner_id IS DISTINCT FROM p_user_id THEN RAISE EXCEPTION 'Twitch account already linked'; END IF;
  UPDATE public.user_premium_status SET is_premium=false,premium_expires_at=now(),updated_at=now()
    WHERE user_id=p_user_id AND premium_source='twitch' AND EXISTS (
      SELECT 1 FROM public.profiles WHERE id=p_user_id AND twitch_user_id IS DISTINCT FROM p_twitch_user_id
    );
  UPDATE public.profiles SET twitch_user_id=p_twitch_user_id WHERE id=p_user_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Profile missing'; END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.bind_verified_twitch_account(uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.bind_verified_twitch_account(uuid,text) TO service_role;

-- The mirror is for display only; even a broad profile UPDATE policy cannot
-- establish entitlement ownership. Unrelated edits to legacy profiles survive.
CREATE OR REPLACE FUNCTION public.guard_twitch_profile_binding()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE bound_id text;
BEGIN
  IF TG_OP='UPDATE' AND NEW.twitch_user_id IS NOT DISTINCT FROM OLD.twitch_user_id THEN RETURN NEW; END IF;
  SELECT twitch_user_id INTO bound_id FROM public.twitch_account_bindings WHERE user_id=NEW.id;
  IF NEW.twitch_user_id IS DISTINCT FROM bound_id THEN RAISE EXCEPTION 'Use verified Twitch linking'; END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.guard_twitch_profile_binding() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS guard_twitch_profile_binding ON public.profiles;
CREATE TRIGGER guard_twitch_profile_binding BEFORE INSERT OR UPDATE OF twitch_user_id ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.guard_twitch_profile_binding();

CREATE OR REPLACE FUNCTION public.disconnect_my_twitch_account()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=auth.uid();
BEGIN
  IF u IS NULL THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  -- All binding changes also lock the app user, serializing concurrent links.
  PERFORM 1 FROM auth.users WHERE id=u FOR UPDATE;
  DELETE FROM public.twitch_account_bindings WHERE user_id=u;
  UPDATE public.profiles SET twitch_user_id=NULL WHERE id=u;
  UPDATE public.user_premium_status SET is_premium=false,premium_expires_at=now(),updated_at=now()
    WHERE user_id=u AND premium_source='twitch';
END;
$$;
REVOKE ALL ON FUNCTION public.disconnect_my_twitch_account() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.disconnect_my_twitch_account() TO authenticated;

CREATE OR REPLACE FUNCTION public.get_my_twitch_binding()
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
  SELECT twitch_user_id FROM public.twitch_account_bindings WHERE user_id=auth.uid();
$$;
REVOKE ALL ON FUNCTION public.get_my_twitch_binding() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_my_twitch_binding() TO authenticated;

CREATE OR REPLACE FUNCTION public.apply_twitch_event(
  p_message_id text,p_body_hash text,p_signed_at timestamptz,
  p_twitch_user_id text DEFAULT NULL,p_active boolean DEFAULT NULL
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_inserted text; v_old public.twitch_entitlement_state%ROWTYPE; v_user uuid; v_expiry timestamptz;
BEGIN
  INSERT INTO public.twitch_event_receipts(message_id,body_hash,signed_at)
    VALUES(p_message_id,p_body_hash,p_signed_at) ON CONFLICT DO NOTHING RETURNING message_id INTO v_inserted;
  IF v_inserted IS NULL THEN
    IF NOT EXISTS(SELECT 1 FROM public.twitch_event_receipts WHERE message_id=p_message_id AND body_hash=p_body_hash AND signed_at=p_signed_at) THEN
      RAISE EXCEPTION 'Message conflict';
    END IF;
    RETURN;
  END IF;
  IF p_twitch_user_id IS NULL OR p_active IS NULL THEN RETURN; END IF;
  -- Lock even the first observation for this Twitch account.
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('twitch:'||p_twitch_user_id,0));
  SELECT * INTO v_old FROM public.twitch_entitlement_state WHERE twitch_user_id=p_twitch_user_id;
  -- Equal-time inactive observations win; old deliveries cannot reactivate access.
  IF FOUND AND (v_old.observed_at>p_signed_at OR (v_old.observed_at=p_signed_at AND NOT v_old.active)) THEN RETURN; END IF;
  SELECT user_id INTO v_user FROM public.twitch_account_bindings WHERE twitch_user_id=p_twitch_user_id;
  IF v_user IS NOT NULL THEN
    PERFORM 1 FROM auth.users WHERE id=v_user FOR UPDATE;
    -- Disconnect may have committed while we waited for this user lock.
    SELECT user_id INTO v_user FROM public.twitch_account_bindings WHERE twitch_user_id=p_twitch_user_id;
  END IF;
  v_expiry:=CASE WHEN p_active THEN p_signed_at+interval '33 days'
    ELSE least(coalesce(v_old.expires_at,(SELECT premium_expires_at FROM public.user_premium_status WHERE user_id=v_user AND premium_source='twitch' AND is_premium),p_signed_at),p_signed_at+interval '3 days') END;
  INSERT INTO public.twitch_entitlement_state VALUES(p_twitch_user_id,p_signed_at,p_active,v_expiry)
    ON CONFLICT(twitch_user_id) DO UPDATE SET observed_at=EXCLUDED.observed_at,active=EXCLUDED.active,expires_at=EXCLUDED.expires_at;
  IF v_user IS NULL THEN RETURN; END IF;
  INSERT INTO public.user_premium_status(user_id,is_premium,premium_source,premium_expires_at,updated_at)
    VALUES(v_user,v_expiry>now(),'twitch',v_expiry,now())
    ON CONFLICT(user_id) DO UPDATE SET is_premium=EXCLUDED.is_premium,premium_source='twitch',premium_expires_at=EXCLUDED.premium_expires_at,updated_at=now()
      WHERE public.user_premium_status.premium_source='twitch'
        OR NOT coalesce(public.user_premium_status.is_premium,false)
        OR public.user_premium_status.premium_expires_at<=now();
END;
$$;
REVOKE ALL ON FUNCTION public.apply_twitch_event(text,text,timestamptz,text,boolean) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.apply_twitch_event(text,text,timestamptz,text,boolean) TO service_role;

CREATE OR REPLACE FUNCTION public.effective_premium_entitlement(p_user_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  WITH candidates AS (
    SELECT p.premium_source, p.premium_since, p.premium_expires_at, 0 AS priority
    FROM public.user_premium_status p
    WHERE p.user_id = p_user_id AND p.is_premium
      AND (p.premium_expires_at IS NULL OR p.premium_expires_at > now())
      -- Once Stripe has authoritative records, a stale legacy flag must not
      -- resurrect a canceled subscription.
      AND (p.premium_source IS DISTINCT FROM 'stripe' OR NOT EXISTS (
        SELECT 1 FROM public.stripe_customers c
        JOIN public.stripe_subscriptions s ON s.customer_id = c.customer_id
        WHERE c.user_id = p.user_id
      ))
      AND (p.premium_source IS DISTINCT FROM 'twitch' OR NOT EXISTS (
        SELECT 1 FROM public.twitch_account_bindings b
        JOIN public.twitch_entitlement_state t USING(twitch_user_id)
        WHERE b.user_id=p.user_id
      ))
    UNION ALL
    SELECT 'stripe', NULL::timestamptz, s.expires_at, 1
    FROM public.stripe_customers c
    JOIN public.stripe_subscriptions s ON s.customer_id = c.customer_id
    WHERE c.user_id = p_user_id AND s.status = 'active' AND s.expires_at > now()
    UNION ALL
    -- An inactive observation may retain the existing bounded grace period.
    SELECT 'twitch', NULL::timestamptz, t.expires_at, 2
    FROM public.twitch_account_bindings b
    JOIN public.twitch_entitlement_state t USING(twitch_user_id)
    WHERE b.user_id=p_user_id AND t.expires_at>now()
  )
  SELECT coalesce((
    SELECT jsonb_build_object('is_premium', true,
      'premium_source', premium_source, 'premium_since', premium_since,
      'premium_expires_at', premium_expires_at)
    FROM candidates
    ORDER BY priority, premium_expires_at DESC NULLS FIRST
    LIMIT 1
  ), jsonb_build_object('is_premium', false, 'premium_source', NULL,
    'premium_since', NULL, 'premium_expires_at', NULL));
$$;
REVOKE ALL ON FUNCTION public.effective_premium_entitlement(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.effective_premium_entitlement(uuid) TO service_role;

-- Source: 20260912120000_store_subscription_bindings.sql
CREATE TABLE IF NOT EXISTS public.store_subscription_bindings (
  platform text NOT NULL CHECK(platform IN ('app_store','google_play')),
  subscription_key text NOT NULL,
  -- Retain ownership tombstones after account deletion; do not reassign purchases.
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  PRIMARY KEY(platform,subscription_key)
);
CREATE INDEX IF NOT EXISTS store_subscription_bindings_user_idx ON public.store_subscription_bindings(user_id);
ALTER TABLE public.store_subscription_bindings ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.store_subscription_bindings FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.store_subscription_bindings TO service_role;
ALTER TABLE public.store_purchase_events ADD COLUMN IF NOT EXISTS subscription_key text;
ALTER TABLE public.store_purchase_events ADD COLUMN IF NOT EXISTS verified_at timestamptz;
CREATE INDEX IF NOT EXISTS store_purchase_events_subscription_idx
  ON public.store_purchase_events(platform,subscription_key);

-- Called only inside verified fulfillment. Serializing each store also orders
-- replacement-token ownership claims, including previously unseen old tokens.
CREATE OR REPLACE FUNCTION public.bind_store_subscription(
  p_user_id uuid,p_platform text,p_key text,p_linked_key text,p_account_bound boolean
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE owner_id uuid; k text;
BEGIN
  IF p_platform IS NULL OR p_platform NOT IN ('app_store','google_play') OR p_key IS NULL
    OR p_key !~ '^(production|sandbox):[0-9a-f]+$' THEN RAISE EXCEPTION 'Invalid subscription identity'; END IF;
  IF p_linked_key IS NOT NULL AND (p_platform<>'google_play'
    OR p_linked_key !~ '^(production|sandbox):[0-9a-f]+$'
    OR split_part(p_linked_key,':',1)<>split_part(p_key,':',1)) THEN RAISE EXCEPTION 'Invalid replacement identity'; END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('store:'||p_platform,0));
  -- Lock before foreign-key inserts to avoid concurrent stores both upgrading
  -- a key-share lock on this user during fulfillment.
  PERFORM 1 FROM auth.users WHERE id=p_user_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Unknown user'; END IF;
  SELECT user_id INTO owner_id FROM public.store_subscription_bindings WHERE platform=p_platform AND subscription_key=p_key;
  IF NOT FOUND AND NOT coalesce(p_account_bound,false) THEN
    SELECT user_id INTO owner_id FROM public.store_subscription_bindings WHERE platform=p_platform AND subscription_key=p_linked_key;
    IF NOT FOUND OR owner_id IS DISTINCT FROM p_user_id THEN
      RAISE EXCEPTION 'Subscription ownership needs verification';
    END IF;
  END IF;
  FOREACH k IN ARRAY ARRAY[p_key,p_linked_key] LOOP
    IF k IS NULL THEN CONTINUE; END IF;
    INSERT INTO public.store_subscription_bindings VALUES(p_platform,k,p_user_id) ON CONFLICT DO NOTHING;
    SELECT user_id INTO owner_id FROM public.store_subscription_bindings WHERE platform=p_platform AND subscription_key=k;
    IF owner_id IS DISTINCT FROM p_user_id THEN RAISE EXCEPTION 'Subscription belongs to another account'; END IF;
  END LOOP;
END;
$$;
REVOKE ALL ON FUNCTION public.bind_store_subscription(uuid,text,text,text,boolean) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.effective_premium_entitlement(p_user_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  WITH candidates AS (
    SELECT p.premium_source, p.premium_since, p.premium_expires_at, 0 AS priority
    FROM public.user_premium_status p
    WHERE p.user_id = p_user_id AND p.is_premium
      AND (p.premium_expires_at IS NULL OR p.premium_expires_at > now())
      -- Once Stripe has authoritative records, a stale legacy flag must not
      -- resurrect a canceled subscription.
      AND (p.premium_source IS DISTINCT FROM 'stripe' OR NOT EXISTS (
        SELECT 1 FROM public.stripe_customers c
        JOIN public.stripe_subscriptions s ON s.customer_id = c.customer_id
        WHERE c.user_id = p.user_id
      ))
      AND (p.premium_source IS DISTINCT FROM 'twitch' OR NOT EXISTS (
        SELECT 1 FROM public.twitch_account_bindings b
        JOIN public.twitch_entitlement_state t USING(twitch_user_id)
        WHERE b.user_id=p.user_id
      ))
      AND NOT EXISTS (
        SELECT 1 FROM public.store_purchase_events e
        WHERE e.user_id=p.user_id AND e.product_type='subscription' AND e.subscription_key IS NOT NULL
          AND p.premium_source=CASE e.platform WHEN 'app_store' THEN 'apple' ELSE 'google' END
      )
    UNION ALL
    SELECT 'stripe', NULL::timestamptz, s.expires_at, 1
    FROM public.stripe_customers c
    JOIN public.stripe_subscriptions s ON s.customer_id = c.customer_id
    WHERE c.user_id = p_user_id AND s.status = 'active' AND s.expires_at > now()
    UNION ALL
    -- An inactive observation may retain the existing bounded grace period.
    SELECT 'twitch', NULL::timestamptz, t.expires_at, 2
    FROM public.twitch_account_bindings b
    JOIN public.twitch_entitlement_state t USING(twitch_user_id)
    WHERE b.user_id=p_user_id AND t.expires_at>now()
    UNION ALL
    SELECT CASE e.platform WHEN 'app_store' THEN 'apple' ELSE 'google' END,
      e.purchased_at, e.expires_at, 3
    FROM public.store_purchase_events e
    JOIN public.store_subscription_bindings b ON b.platform=e.platform AND b.subscription_key=e.subscription_key AND b.user_id=e.user_id
    WHERE e.user_id=p_user_id AND e.product_type='subscription' AND e.expires_at>now()
      AND ((e.platform='app_store' AND e.store_state='ACTIVE') OR
        (e.platform='google_play' AND e.store_state IN ('SUBSCRIPTION_STATE_ACTIVE','SUBSCRIPTION_STATE_IN_GRACE_PERIOD','SUBSCRIPTION_STATE_CANCELED')))
  )
  SELECT coalesce((
    SELECT jsonb_build_object('is_premium', true,
      'premium_source', premium_source, 'premium_since', premium_since,
      'premium_expires_at', premium_expires_at)
    FROM candidates
    ORDER BY priority, premium_expires_at DESC NULLS FIRST
    LIMIT 1
  ), jsonb_build_object('is_premium', false, 'premium_source', NULL,
    'premium_since', NULL, 'premium_expires_at', NULL));
$$;
REVOKE ALL ON FUNCTION public.effective_premium_entitlement(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.effective_premium_entitlement(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.fulfill_verified_store_purchase(
  p_user_id uuid,
  p_platform text,
  p_transaction_id text,
  p_product_id text,
  p_product_type text,
  p_store_state text,
  p_purchased_at timestamptz DEFAULT NULL,
  p_expires_at timestamptz DEFAULT NULL,
  p_is_test boolean DEFAULT false,
  p_metadata jsonb DEFAULT '{}'::jsonb
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_inserted_id uuid;
  v_existing public.store_purchase_events%ROWTYPE;
  v_pack_type text;
  v_credits integer;
  v_price numeric(10, 2);
  v_effective jsonb;
  v_key text;
  v_observed timestamptz;
BEGIN
  IF p_user_id IS NULL OR p_transaction_id IS NULL OR length(p_transaction_id) < 8 THEN
    RAISE EXCEPTION 'Invalid verified purchase identity';
  END IF;

  IF p_platform NOT IN ('google_play', 'app_store') OR
     p_product_type NOT IN ('subscription', 'consumable') THEN
    RAISE EXCEPTION 'Invalid verified purchase attributes';
  END IF;

  IF p_product_type='subscription' THEN
    IF p_product_id IS DISTINCT FROM 'statusxp_premium_monthly'
      OR p_expires_at IS NULL OR p_expires_at<=now()
      OR NOT coalesce((p_platform='app_store' AND p_store_state='ACTIVE') OR
        (p_platform='google_play' AND p_store_state IN ('SUBSCRIPTION_STATE_ACTIVE','SUBSCRIPTION_STATE_IN_GRACE_PERIOD','SUBSCRIPTION_STATE_CANCELED')),false)
      THEN RAISE EXCEPTION 'Invalid active subscription'; END IF;
    v_key:=p_metadata->>'subscriptionKey';
    v_observed:=(p_metadata->>'verifiedAt')::timestamptz;
    IF v_observed IS NULL OR v_observed>clock_timestamp()+interval '1 minute' THEN RAISE EXCEPTION 'Invalid verification time'; END IF;
    IF split_part(v_key,':',1) IS DISTINCT FROM (CASE WHEN p_is_test THEN 'sandbox' ELSE 'production' END)
      THEN RAISE EXCEPTION 'Subscription environment mismatch'; END IF;
    PERFORM public.bind_store_subscription(p_user_id,p_platform,v_key,p_metadata->>'linkedSubscriptionKey',p_metadata->'accountBound'='true'::jsonb);
  END IF;
  PERFORM 1 FROM auth.users WHERE id=p_user_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Unknown user'; END IF;

  INSERT INTO public.store_purchase_events (
    user_id, platform, store_transaction_id, product_id, product_type,
    store_state, purchased_at, expires_at, is_test, metadata, subscription_key, verified_at
  ) VALUES (
    p_user_id, p_platform, p_transaction_id, p_product_id, p_product_type,
    p_store_state, p_purchased_at, p_expires_at, p_is_test, p_metadata, v_key, v_observed
  )
  ON CONFLICT (platform, store_transaction_id) DO NOTHING
  RETURNING id INTO v_inserted_id;

  IF v_inserted_id IS NULL THEN
    SELECT * INTO v_existing
    FROM public.store_purchase_events
    WHERE platform = p_platform
      AND store_transaction_id = p_transaction_id;

    IF v_existing.user_id <> p_user_id OR v_existing.product_id <> p_product_id OR v_existing.product_type <> p_product_type
      OR v_existing.is_test <> p_is_test OR (v_existing.subscription_key IS NOT NULL AND v_existing.subscription_key IS DISTINCT FROM v_key) THEN
      RAISE EXCEPTION 'Verified purchase is already bound to another entitlement';
    END IF;

    IF p_product_type='consumable' THEN
      RETURN jsonb_build_object('success', true, 'already_processed', true);
    END IF;
    -- Re-verification can extend grace or shorten an existing period. An older
    -- in-flight store lookup must not overwrite a newer observation.
    UPDATE public.store_purchase_events SET subscription_key=v_key, verified_at=v_observed,
      store_state=p_store_state, expires_at=p_expires_at
      WHERE id=v_existing.id AND (verified_at IS NULL OR verified_at<v_observed);

  END IF;

  IF p_product_type = 'consumable' THEN
    SELECT pack_type, credits, price
      INTO v_pack_type, v_credits, v_price
    FROM (VALUES
      ('statusxp_ai_pack_small',  'small',  20,  1.99::numeric),
      ('statusxp_ai_pack_medium', 'medium', 60,  4.99::numeric),
      ('statusxp_ai_pack_large',  'large', 150, 9.99::numeric)
    ) AS products(product_id, pack_type, credits, price)
    WHERE product_id = p_product_id;

    IF v_credits IS NULL THEN
      RAISE EXCEPTION 'Unknown consumable product';
    END IF;

    INSERT INTO public.user_ai_credits (user_id, pack_credits)
    VALUES (p_user_id, v_credits)
    ON CONFLICT (user_id) DO UPDATE SET
      pack_credits = public.user_ai_credits.pack_credits + EXCLUDED.pack_credits,
      updated_at = now();

    INSERT INTO public.user_ai_pack_purchases (
      user_id, pack_type, credits_purchased, price_paid, platform
    ) VALUES (p_user_id, v_pack_type, v_credits, v_price, p_platform);
  ELSIF p_product_id = 'statusxp_premium_monthly' THEN
    v_effective:=public.effective_premium_entitlement(p_user_id);
    INSERT INTO public.user_premium_status(user_id,is_premium,premium_source,premium_since,premium_expires_at,updated_at)
      VALUES(p_user_id,(v_effective->>'is_premium')::boolean,v_effective->>'premium_source',
        (v_effective->>'premium_since')::timestamptz,(v_effective->>'premium_expires_at')::timestamptz,now())
      ON CONFLICT(user_id) DO UPDATE SET is_premium=EXCLUDED.is_premium,premium_source=EXCLUDED.premium_source,
        premium_since=EXCLUDED.premium_since,premium_expires_at=EXCLUDED.premium_expires_at,updated_at=now();
  ELSE
    RAISE EXCEPTION 'Unknown subscription product';
  END IF;

  RETURN jsonb_build_object('success', true, 'already_processed', v_inserted_id IS NULL);
END;
$$;

REVOKE ALL ON FUNCTION public.fulfill_verified_store_purchase(
  uuid, text, text, text, text, text, timestamptz, timestamptz, boolean, jsonb
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fulfill_verified_store_purchase(
  uuid, text, text, text, text, text, timestamptz, timestamptz, boolean, jsonb
) TO service_role;


-- Source: 20260912130000_google_play_notifications.sql
CREATE TABLE IF NOT EXISTS public.google_play_notification_receipts (
  message_id text PRIMARY KEY, body_hash text NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.google_play_subscription_state (
  subscription_key text PRIMARY KEY,
  store_state text NOT NULL,
  expires_at timestamptz,
  observed_at timestamptz NOT NULL
);
ALTER TABLE public.google_play_subscription_state ADD COLUMN IF NOT EXISTS superseded boolean NOT NULL DEFAULT false;
ALTER TABLE public.google_play_notification_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.google_play_subscription_state ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.google_play_notification_receipts,public.google_play_subscription_state FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.google_play_notification_receipts,public.google_play_subscription_state TO service_role;

CREATE OR REPLACE FUNCTION public.record_google_play_state(p_key text,p_state text,p_expiry timestamptz,p_observed timestamptz)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF p_key IS NULL OR p_key !~ '^(production|sandbox):[0-9a-f]{64}$' OR p_state IS NULL OR p_state NOT IN (
    'SUBSCRIPTION_STATE_ACTIVE','SUBSCRIPTION_STATE_IN_GRACE_PERIOD','SUBSCRIPTION_STATE_CANCELED',
    'SUBSCRIPTION_STATE_PENDING','SUBSCRIPTION_STATE_PAUSED','SUBSCRIPTION_STATE_ON_HOLD',
    'SUBSCRIPTION_STATE_EXPIRED','SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED')
    OR p_observed IS NULL OR p_observed>clock_timestamp()+interval '1 minute'
    OR (p_expiry IS NULL AND p_state IN ('SUBSCRIPTION_STATE_ACTIVE','SUBSCRIPTION_STATE_IN_GRACE_PERIOD','SUBSCRIPTION_STATE_CANCELED'))
    THEN RAISE EXCEPTION 'Invalid Google state'; END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('store:google_play',0));
  INSERT INTO public.google_play_subscription_state(subscription_key,store_state,expires_at,observed_at) VALUES(p_key,p_state,p_expiry,p_observed)
    ON CONFLICT(subscription_key) DO UPDATE SET store_state=EXCLUDED.store_state,expires_at=EXCLUDED.expires_at,observed_at=EXCLUDED.observed_at
    WHERE public.google_play_subscription_state.observed_at<EXCLUDED.observed_at
      OR (public.google_play_subscription_state.observed_at=EXCLUDED.observed_at
        AND EXCLUDED.store_state NOT IN ('SUBSCRIPTION_STATE_ACTIVE','SUBSCRIPTION_STATE_IN_GRACE_PERIOD','SUBSCRIPTION_STATE_CANCELED'));
END;
$$;
REVOKE ALL ON FUNCTION public.record_google_play_state(text,text,timestamptz,timestamptz) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.retire_replaced_google_token(p_old text,p_new text,p_observed timestamptz)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF p_old IS NULL THEN RETURN; END IF;
  IF p_old=p_new OR p_old !~ '^(production|sandbox):[0-9a-f]{64}$'
    OR split_part(p_old,':',1)<>split_part(p_new,':',1) THEN RAISE EXCEPTION 'Invalid replacement'; END IF;
  INSERT INTO public.google_play_subscription_state(subscription_key,store_state,expires_at,observed_at,superseded)
    VALUES(p_old,'SUBSCRIPTION_STATE_EXPIRED',p_observed,p_observed,true)
    ON CONFLICT(subscription_key) DO UPDATE SET superseded=true;
END;
$$;
REVOKE ALL ON FUNCTION public.retire_replaced_google_token(text,text,timestamptz) FROM PUBLIC,anon,authenticated,service_role;

-- Mobile verification participates in the same ordering as push notifications.
CREATE OR REPLACE FUNCTION public.track_verified_google_state()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF NEW.platform='google_play' AND NEW.product_type='subscription' AND NEW.subscription_key IS NOT NULL AND NEW.verified_at IS NOT NULL THEN
    PERFORM public.record_google_play_state(NEW.subscription_key,NEW.store_state,NEW.expires_at,NEW.verified_at);
    PERFORM public.retire_replaced_google_token(NEW.metadata->>'linkedSubscriptionKey',NEW.subscription_key,NEW.verified_at);
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.track_verified_google_state() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS track_verified_google_state ON public.store_purchase_events;
CREATE TRIGGER track_verified_google_state AFTER INSERT OR UPDATE OF store_state,expires_at,verified_at ON public.store_purchase_events
FOR EACH ROW EXECUTE FUNCTION public.track_verified_google_state();

CREATE OR REPLACE FUNCTION public.apply_google_play_notification(
  p_message_id text,p_body_hash text,p_observed_at timestamptz,p_snapshot jsonb,p_expected_user uuid DEFAULT NULL
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE inserted text; u uuid; k text:=p_snapshot->>'subscriptionKey'; linked text:=p_snapshot->>'linkedSubscriptionKey'; e jsonb;
BEGIN
  IF p_message_id IS NULL OR p_message_id !~ '^[0-9]{1,100}$' OR p_body_hash IS NULL OR p_body_hash !~ '^[0-9a-f]{64}$' THEN RAISE EXCEPTION 'Invalid receipt'; END IF;
  INSERT INTO public.google_play_notification_receipts(message_id,body_hash) VALUES(p_message_id,p_body_hash)
    ON CONFLICT DO NOTHING RETURNING message_id INTO inserted;
  IF inserted IS NULL THEN
    IF NOT EXISTS(SELECT 1 FROM public.google_play_notification_receipts WHERE message_id=p_message_id AND body_hash=p_body_hash) THEN RAISE EXCEPTION 'Message conflict'; END IF;
    RETURN;
  END IF;
  IF p_snapshot IS NULL THEN RETURN; END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('store:google_play',0));
  SELECT user_id INTO u FROM public.store_subscription_bindings WHERE platform='google_play' AND subscription_key=k;
  IF NOT FOUND THEN SELECT user_id INTO u FROM public.store_subscription_bindings WHERE platform='google_play' AND subscription_key=linked; END IF;
  IF u IS DISTINCT FROM p_expected_user THEN RAISE EXCEPTION 'Binding changed'; END IF;
  IF u IS NOT NULL THEN
    PERFORM public.bind_store_subscription(u,'google_play',k,linked,false);
  END IF;
  PERFORM public.record_google_play_state(k,p_snapshot->>'state',(p_snapshot->>'expiresAt')::timestamptz,p_observed_at);
  IF p_snapshot->>'state' NOT IN ('SUBSCRIPTION_STATE_PENDING','SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED') THEN
    PERFORM public.retire_replaced_google_token(linked,k,p_observed_at);
  END IF;
  IF u IS NOT NULL THEN
    e:=public.effective_premium_entitlement(u);
    INSERT INTO public.user_premium_status(user_id,is_premium,premium_source,premium_since,premium_expires_at,updated_at)
      VALUES(u,(e->>'is_premium')::boolean,e->>'premium_source',(e->>'premium_since')::timestamptz,(e->>'premium_expires_at')::timestamptz,now())
      ON CONFLICT(user_id) DO UPDATE SET is_premium=EXCLUDED.is_premium,premium_source=EXCLUDED.premium_source,
        premium_since=EXCLUDED.premium_since,premium_expires_at=EXCLUDED.premium_expires_at,updated_at=now();
  END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.apply_google_play_notification(text,text,timestamptz,jsonb,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.apply_google_play_notification(text,text,timestamptz,jsonb,uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.effective_premium_entitlement(p_user_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  WITH candidates AS (
    SELECT p.premium_source, p.premium_since, p.premium_expires_at, 0 AS priority
    FROM public.user_premium_status p
    WHERE p.user_id = p_user_id AND p.is_premium
      AND (p.premium_expires_at IS NULL OR p.premium_expires_at > now())
      -- Once Stripe has authoritative records, a stale legacy flag must not
      -- resurrect a canceled subscription.
      AND (p.premium_source IS DISTINCT FROM 'stripe' OR NOT EXISTS (
        SELECT 1 FROM public.stripe_customers c
        JOIN public.stripe_subscriptions s ON s.customer_id = c.customer_id
        WHERE c.user_id = p.user_id
      ))
      AND (p.premium_source IS DISTINCT FROM 'twitch' OR NOT EXISTS (
        SELECT 1 FROM public.twitch_account_bindings b
        JOIN public.twitch_entitlement_state t USING(twitch_user_id)
        WHERE b.user_id=p.user_id
      ))
      AND NOT EXISTS (
        SELECT 1 FROM public.store_purchase_events e
        WHERE e.user_id=p.user_id AND e.product_type='subscription' AND e.subscription_key IS NOT NULL
          AND p.premium_source=CASE e.platform WHEN 'app_store' THEN 'apple' ELSE 'google' END
      )
      AND (p.premium_source IS DISTINCT FROM 'google' OR NOT EXISTS (
        SELECT 1 FROM public.google_play_subscription_state g
        JOIN public.store_subscription_bindings b ON b.platform='google_play' AND b.subscription_key=g.subscription_key
        WHERE b.user_id=p.user_id
      ))
    UNION ALL
    SELECT 'stripe', NULL::timestamptz, s.expires_at, 1
    FROM public.stripe_customers c
    JOIN public.stripe_subscriptions s ON s.customer_id = c.customer_id
    WHERE c.user_id = p_user_id AND s.status = 'active' AND s.expires_at > now()
    UNION ALL
    -- An inactive observation may retain the existing bounded grace period.
    SELECT 'twitch', NULL::timestamptz, t.expires_at, 2
    FROM public.twitch_account_bindings b
    JOIN public.twitch_entitlement_state t USING(twitch_user_id)
    WHERE b.user_id=p_user_id AND t.expires_at>now()
    UNION ALL
    SELECT CASE e.platform WHEN 'app_store' THEN 'apple' ELSE 'google' END,
      e.purchased_at, e.expires_at, 3
    FROM public.store_purchase_events e
    JOIN public.store_subscription_bindings b ON b.platform=e.platform AND b.subscription_key=e.subscription_key AND b.user_id=e.user_id
    WHERE e.user_id=p_user_id AND e.product_type='subscription' AND e.expires_at>now()
      AND (e.platform<>'google_play' OR NOT EXISTS(SELECT 1 FROM public.google_play_subscription_state g WHERE g.subscription_key=e.subscription_key))
      AND ((e.platform='app_store' AND e.store_state='ACTIVE') OR
        (e.platform='google_play' AND e.store_state IN ('SUBSCRIPTION_STATE_ACTIVE','SUBSCRIPTION_STATE_IN_GRACE_PERIOD','SUBSCRIPTION_STATE_CANCELED')))
    UNION ALL
    SELECT 'google',NULL::timestamptz,g.expires_at,3
    FROM public.google_play_subscription_state g
    JOIN public.store_subscription_bindings b ON b.platform='google_play' AND b.subscription_key=g.subscription_key
    WHERE b.user_id=p_user_id AND g.expires_at>now() AND NOT g.superseded
      AND g.store_state IN ('SUBSCRIPTION_STATE_ACTIVE','SUBSCRIPTION_STATE_IN_GRACE_PERIOD','SUBSCRIPTION_STATE_CANCELED')
  )
  SELECT coalesce((
    SELECT jsonb_build_object('is_premium', true,
      'premium_source', premium_source, 'premium_since', premium_since,
      'premium_expires_at', premium_expires_at)
    FROM candidates
    ORDER BY priority, premium_expires_at DESC NULLS FIRST
    LIMIT 1
  ), jsonb_build_object('is_premium', false, 'premium_source', NULL,
    'premium_since', NULL, 'premium_expires_at', NULL));
$$;
REVOKE ALL ON FUNCTION public.effective_premium_entitlement(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.effective_premium_entitlement(uuid) TO service_role;


-- Source: 20260912140000_apple_notifications.sql
CREATE TABLE IF NOT EXISTS public.apple_notification_receipts (
  message_id uuid PRIMARY KEY, body_hash text NOT NULL, received_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.apple_subscription_state (
  subscription_key text PRIMARY KEY, status integer NOT NULL CHECK(status BETWEEN 1 AND 5),
  expires_at timestamptz, observed_at timestamptz NOT NULL
);
ALTER TABLE public.apple_notification_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.apple_subscription_state ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.apple_notification_receipts,public.apple_subscription_state FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.apple_notification_receipts,public.apple_subscription_state TO service_role;
CREATE OR REPLACE FUNCTION public.record_apple_state(p_key text,p_status integer,p_expiry timestamptz,p_observed timestamptz)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF p_key IS NULL OR p_key !~ '^(production|sandbox):[0-9]+$' OR p_status IS NULL OR p_status NOT BETWEEN 1 AND 5
    OR p_observed IS NULL OR p_observed>clock_timestamp()+interval '1 minute'
    OR (p_status IN (1,4) AND p_expiry IS NULL) THEN RAISE EXCEPTION 'Invalid Apple state'; END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('store:app_store',0));
  INSERT INTO public.apple_subscription_state VALUES(p_key,p_status,p_expiry,p_observed)
    ON CONFLICT(subscription_key) DO UPDATE SET status=EXCLUDED.status,expires_at=EXCLUDED.expires_at,observed_at=EXCLUDED.observed_at
    WHERE public.apple_subscription_state.observed_at<EXCLUDED.observed_at
      OR (public.apple_subscription_state.observed_at=EXCLUDED.observed_at AND EXCLUDED.status NOT IN (1,4));
END;
$$;
REVOKE ALL ON FUNCTION public.record_apple_state(text,integer,timestamptz,timestamptz) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.track_verified_apple_state()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF NEW.platform='app_store' AND NEW.product_type='subscription' AND NEW.subscription_key IS NOT NULL
    AND NEW.verified_at IS NOT NULL AND NEW.metadata->>'appleStatus' IS NOT NULL THEN
    PERFORM public.record_apple_state(NEW.subscription_key,(NEW.metadata->>'appleStatus')::integer,NEW.expires_at,NEW.verified_at);
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.track_verified_apple_state() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS track_verified_apple_state ON public.store_purchase_events;
CREATE TRIGGER track_verified_apple_state AFTER INSERT OR UPDATE OF store_state,expires_at,verified_at ON public.store_purchase_events
FOR EACH ROW EXECUTE FUNCTION public.track_verified_apple_state();
CREATE OR REPLACE FUNCTION public.apply_apple_notification(
  p_message_id uuid,p_body_hash text,p_observed_at timestamptz,p_snapshot jsonb,p_expected_user uuid DEFAULT NULL
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE inserted uuid; u uuid; k text:=p_snapshot->>'subscriptionKey'; e jsonb;
BEGIN
  IF p_message_id IS NULL OR p_body_hash IS NULL OR p_body_hash !~ '^[0-9a-f]{64}$' THEN RAISE EXCEPTION 'Invalid receipt'; END IF;
  INSERT INTO public.apple_notification_receipts(message_id,body_hash) VALUES(p_message_id,p_body_hash)
    ON CONFLICT DO NOTHING RETURNING message_id INTO inserted;
  IF inserted IS NULL THEN
    IF NOT EXISTS(SELECT 1 FROM public.apple_notification_receipts WHERE message_id=p_message_id AND body_hash=p_body_hash) THEN RAISE EXCEPTION 'Message conflict'; END IF;
    RETURN;
  END IF;
  IF p_snapshot IS NULL THEN RETURN; END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('store:app_store',0));
  SELECT user_id INTO u FROM public.store_subscription_bindings WHERE platform='app_store' AND subscription_key=k;
  IF u IS DISTINCT FROM p_expected_user THEN RAISE EXCEPTION 'Binding changed'; END IF;
  IF u IS NOT NULL THEN PERFORM public.bind_store_subscription(u,'app_store',k,NULL,false); END IF;
  PERFORM public.record_apple_state(k,(p_snapshot->>'status')::integer,(p_snapshot->>'expiresAt')::timestamptz,p_observed_at);
  IF u IS NOT NULL THEN
    e:=public.effective_premium_entitlement(u);
    INSERT INTO public.user_premium_status(user_id,is_premium,premium_source,premium_since,premium_expires_at,updated_at)
      VALUES(u,(e->>'is_premium')::boolean,e->>'premium_source',(e->>'premium_since')::timestamptz,(e->>'premium_expires_at')::timestamptz,now())
      ON CONFLICT(user_id) DO UPDATE SET is_premium=EXCLUDED.is_premium,premium_source=EXCLUDED.premium_source,
        premium_since=EXCLUDED.premium_since,premium_expires_at=EXCLUDED.premium_expires_at,updated_at=now();
  END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.apply_apple_notification(uuid,text,timestamptz,jsonb,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.apply_apple_notification(uuid,text,timestamptz,jsonb,uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.effective_premium_entitlement(p_user_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  WITH candidates AS (
    SELECT p.premium_source, p.premium_since, p.premium_expires_at, 0 AS priority
    FROM public.user_premium_status p
    WHERE p.user_id = p_user_id AND p.is_premium
      AND (p.premium_expires_at IS NULL OR p.premium_expires_at > now())
      -- Once Stripe has authoritative records, a stale legacy flag must not
      -- resurrect a canceled subscription.
      AND (p.premium_source IS DISTINCT FROM 'stripe' OR NOT EXISTS (
        SELECT 1 FROM public.stripe_customers c
        JOIN public.stripe_subscriptions s ON s.customer_id = c.customer_id
        WHERE c.user_id = p.user_id
      ))
      AND (p.premium_source IS DISTINCT FROM 'twitch' OR NOT EXISTS (
        SELECT 1 FROM public.twitch_account_bindings b
        JOIN public.twitch_entitlement_state t USING(twitch_user_id)
        WHERE b.user_id=p.user_id
      ))
      AND NOT EXISTS (
        SELECT 1 FROM public.store_purchase_events e
        WHERE e.user_id=p.user_id AND e.product_type='subscription' AND e.subscription_key IS NOT NULL
          AND p.premium_source=CASE e.platform WHEN 'app_store' THEN 'apple' ELSE 'google' END
      )
      AND (p.premium_source IS DISTINCT FROM 'google' OR NOT EXISTS (
        SELECT 1 FROM public.google_play_subscription_state g
        JOIN public.store_subscription_bindings b ON b.platform='google_play' AND b.subscription_key=g.subscription_key
        WHERE b.user_id=p.user_id
      ))
      AND (p.premium_source IS DISTINCT FROM 'apple' OR NOT EXISTS (
        SELECT 1 FROM public.apple_subscription_state a
        JOIN public.store_subscription_bindings b ON b.platform='app_store' AND b.subscription_key=a.subscription_key
        WHERE b.user_id=p.user_id
      ))
    UNION ALL
    SELECT 'stripe', NULL::timestamptz, s.expires_at, 1
    FROM public.stripe_customers c
    JOIN public.stripe_subscriptions s ON s.customer_id = c.customer_id
    WHERE c.user_id = p_user_id AND s.status = 'active' AND s.expires_at > now()
    UNION ALL
    -- An inactive observation may retain the existing bounded grace period.
    SELECT 'twitch', NULL::timestamptz, t.expires_at, 2
    FROM public.twitch_account_bindings b
    JOIN public.twitch_entitlement_state t USING(twitch_user_id)
    WHERE b.user_id=p_user_id AND t.expires_at>now()
    UNION ALL
    SELECT CASE e.platform WHEN 'app_store' THEN 'apple' ELSE 'google' END,
      e.purchased_at, e.expires_at, 3
    FROM public.store_purchase_events e
    JOIN public.store_subscription_bindings b ON b.platform=e.platform AND b.subscription_key=e.subscription_key AND b.user_id=e.user_id
    WHERE e.user_id=p_user_id AND e.product_type='subscription' AND e.expires_at>now()
      AND (e.platform<>'app_store' OR NOT EXISTS(SELECT 1 FROM public.apple_subscription_state a WHERE a.subscription_key=e.subscription_key))
      AND (e.platform<>'google_play' OR NOT EXISTS(SELECT 1 FROM public.google_play_subscription_state g WHERE g.subscription_key=e.subscription_key))
      AND ((e.platform='app_store' AND e.store_state='ACTIVE') OR
        (e.platform='google_play' AND e.store_state IN ('SUBSCRIPTION_STATE_ACTIVE','SUBSCRIPTION_STATE_IN_GRACE_PERIOD','SUBSCRIPTION_STATE_CANCELED')))
    UNION ALL
    SELECT 'google',NULL::timestamptz,g.expires_at,3
    FROM public.google_play_subscription_state g
    JOIN public.store_subscription_bindings b ON b.platform='google_play' AND b.subscription_key=g.subscription_key
    WHERE b.user_id=p_user_id AND g.expires_at>now() AND NOT g.superseded
      AND g.store_state IN ('SUBSCRIPTION_STATE_ACTIVE','SUBSCRIPTION_STATE_IN_GRACE_PERIOD','SUBSCRIPTION_STATE_CANCELED')
    UNION ALL
    SELECT 'apple',NULL::timestamptz,a.expires_at,3
    FROM public.apple_subscription_state a
    JOIN public.store_subscription_bindings b ON b.platform='app_store' AND b.subscription_key=a.subscription_key
    WHERE b.user_id=p_user_id AND a.expires_at>now() AND a.status IN (1,4)
  )
  SELECT coalesce((
    SELECT jsonb_build_object('is_premium', true,
      'premium_source', premium_source, 'premium_since', premium_since,
      'premium_expires_at', premium_expires_at)
    FROM candidates
    ORDER BY priority, premium_expires_at DESC NULLS FIRST
    LIMIT 1
  ), jsonb_build_object('is_premium', false, 'premium_source', NULL,
    'premium_since', NULL, 'premium_expires_at', NULL));
$$;
REVOKE ALL ON FUNCTION public.effective_premium_entitlement(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.effective_premium_entitlement(uuid) TO service_role;


-- Keep the latest signed status metadata when re-verifying an existing period.
CREATE OR REPLACE FUNCTION public.fulfill_verified_store_purchase(
  p_user_id uuid,
  p_platform text,
  p_transaction_id text,
  p_product_id text,
  p_product_type text,
  p_store_state text,
  p_purchased_at timestamptz DEFAULT NULL,
  p_expires_at timestamptz DEFAULT NULL,
  p_is_test boolean DEFAULT false,
  p_metadata jsonb DEFAULT '{}'::jsonb
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_inserted_id uuid;
  v_existing public.store_purchase_events%ROWTYPE;
  v_pack_type text;
  v_credits integer;
  v_price numeric(10, 2);
  v_effective jsonb;
  v_key text;
  v_observed timestamptz;
BEGIN
  IF p_user_id IS NULL OR p_transaction_id IS NULL OR length(p_transaction_id) < 8 THEN
    RAISE EXCEPTION 'Invalid verified purchase identity';
  END IF;

  IF p_platform NOT IN ('google_play', 'app_store') OR
     p_product_type NOT IN ('subscription', 'consumable') THEN
    RAISE EXCEPTION 'Invalid verified purchase attributes';
  END IF;

  IF p_product_type='subscription' THEN
    IF p_product_id IS DISTINCT FROM 'statusxp_premium_monthly'
      OR p_expires_at IS NULL OR p_expires_at<=now()
      OR NOT coalesce((p_platform='app_store' AND p_store_state='ACTIVE') OR
        (p_platform='google_play' AND p_store_state IN ('SUBSCRIPTION_STATE_ACTIVE','SUBSCRIPTION_STATE_IN_GRACE_PERIOD','SUBSCRIPTION_STATE_CANCELED')),false)
      THEN RAISE EXCEPTION 'Invalid active subscription'; END IF;
    v_key:=p_metadata->>'subscriptionKey';
    v_observed:=(p_metadata->>'verifiedAt')::timestamptz;
    IF v_observed IS NULL OR v_observed>clock_timestamp()+interval '1 minute' THEN RAISE EXCEPTION 'Invalid verification time'; END IF;
    IF split_part(v_key,':',1) IS DISTINCT FROM (CASE WHEN p_is_test THEN 'sandbox' ELSE 'production' END)
      THEN RAISE EXCEPTION 'Subscription environment mismatch'; END IF;
    PERFORM public.bind_store_subscription(p_user_id,p_platform,v_key,p_metadata->>'linkedSubscriptionKey',p_metadata->'accountBound'='true'::jsonb);
  END IF;
  PERFORM 1 FROM auth.users WHERE id=p_user_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Unknown user'; END IF;

  INSERT INTO public.store_purchase_events (
    user_id, platform, store_transaction_id, product_id, product_type,
    store_state, purchased_at, expires_at, is_test, metadata, subscription_key, verified_at
  ) VALUES (
    p_user_id, p_platform, p_transaction_id, p_product_id, p_product_type,
    p_store_state, p_purchased_at, p_expires_at, p_is_test, p_metadata, v_key, v_observed
  )
  ON CONFLICT (platform, store_transaction_id) DO NOTHING
  RETURNING id INTO v_inserted_id;

  IF v_inserted_id IS NULL THEN
    SELECT * INTO v_existing
    FROM public.store_purchase_events
    WHERE platform = p_platform
      AND store_transaction_id = p_transaction_id;

    IF v_existing.user_id <> p_user_id OR v_existing.product_id <> p_product_id OR v_existing.product_type <> p_product_type
      OR v_existing.is_test <> p_is_test OR (v_existing.subscription_key IS NOT NULL AND v_existing.subscription_key IS DISTINCT FROM v_key) THEN
      RAISE EXCEPTION 'Verified purchase is already bound to another entitlement';
    END IF;

    IF p_product_type='consumable' THEN
      RETURN jsonb_build_object('success', true, 'already_processed', true);
    END IF;
    -- Re-verification can extend grace or shorten an existing period. An older
    -- in-flight store lookup must not overwrite a newer observation.
    UPDATE public.store_purchase_events SET subscription_key=v_key, verified_at=v_observed,
      store_state=p_store_state, expires_at=p_expires_at, metadata=p_metadata
      WHERE id=v_existing.id AND (verified_at IS NULL OR verified_at<v_observed);

  END IF;

  IF p_product_type = 'consumable' THEN
    SELECT pack_type, credits, price
      INTO v_pack_type, v_credits, v_price
    FROM (VALUES
      ('statusxp_ai_pack_small',  'small',  20,  1.99::numeric),
      ('statusxp_ai_pack_medium', 'medium', 60,  4.99::numeric),
      ('statusxp_ai_pack_large',  'large', 150, 9.99::numeric)
    ) AS products(product_id, pack_type, credits, price)
    WHERE product_id = p_product_id;

    IF v_credits IS NULL THEN
      RAISE EXCEPTION 'Unknown consumable product';
    END IF;

    INSERT INTO public.user_ai_credits (user_id, pack_credits)
    VALUES (p_user_id, v_credits)
    ON CONFLICT (user_id) DO UPDATE SET
      pack_credits = public.user_ai_credits.pack_credits + EXCLUDED.pack_credits,
      updated_at = now();

    INSERT INTO public.user_ai_pack_purchases (
      user_id, pack_type, credits_purchased, price_paid, platform
    ) VALUES (p_user_id, v_pack_type, v_credits, v_price, p_platform);
  ELSIF p_product_id = 'statusxp_premium_monthly' THEN
    v_effective:=public.effective_premium_entitlement(p_user_id);
    INSERT INTO public.user_premium_status(user_id,is_premium,premium_source,premium_since,premium_expires_at,updated_at)
      VALUES(p_user_id,(v_effective->>'is_premium')::boolean,v_effective->>'premium_source',
        (v_effective->>'premium_since')::timestamptz,(v_effective->>'premium_expires_at')::timestamptz,now())
      ON CONFLICT(user_id) DO UPDATE SET is_premium=EXCLUDED.is_premium,premium_source=EXCLUDED.premium_source,
        premium_since=EXCLUDED.premium_since,premium_expires_at=EXCLUDED.premium_expires_at,updated_at=now();
  ELSE
    RAISE EXCEPTION 'Unknown subscription product';
  END IF;

  RETURN jsonb_build_object('success', true, 'already_processed', v_inserted_id IS NULL);
END;
$$;

REVOKE ALL ON FUNCTION public.fulfill_verified_store_purchase(
  uuid, text, text, text, text, text, timestamptz, timestamptz, boolean, jsonb
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fulfill_verified_store_purchase(
  uuid, text, text, text, text, text, timestamptz, timestamptz, boolean, jsonb
) TO service_role;



-- Source: 20260912150000_entitlement_reconciliation_jobs.sql
CREATE TABLE IF NOT EXISTS public.entitlement_reconciliation_jobs (
  provider text NOT NULL CHECK(provider IN ('apple','twitch')),
  subject text NOT NULL,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  next_attempt_at timestamptz NOT NULL DEFAULT now(),
  lease_token uuid,
  lease_expires_at timestamptz,
  attempts integer NOT NULL DEFAULT 0,
  last_success_at timestamptz,
  last_failure_at timestamptz,
  PRIMARY KEY(provider,subject)
);
CREATE INDEX IF NOT EXISTS entitlement_reconciliation_due_idx ON public.entitlement_reconciliation_jobs(next_attempt_at);
ALTER TABLE public.entitlement_reconciliation_jobs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.entitlement_reconciliation_jobs FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.entitlement_reconciliation_jobs TO service_role;

CREATE OR REPLACE FUNCTION public.sync_entitlement_reconciliation_job()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p text; old_subject text; new_subject text; u uuid;
BEGIN
  IF TG_TABLE_NAME='twitch_account_bindings' THEN
    p:='twitch';
    IF TG_OP<>'INSERT' THEN old_subject:=OLD.twitch_user_id; END IF;
    IF TG_OP<>'DELETE' THEN new_subject:=NEW.twitch_user_id; u:=NEW.user_id; END IF;
  ELSE
    p:='apple';
    IF TG_OP<>'INSERT' AND OLD.platform='app_store' THEN old_subject:=OLD.subscription_key; END IF;
    IF TG_OP<>'DELETE' AND NEW.platform='app_store' THEN new_subject:=NEW.subscription_key; u:=NEW.user_id; END IF;
  END IF;
  IF old_subject IS NOT NULL AND (new_subject IS DISTINCT FROM old_subject OR u IS NULL) THEN
    DELETE FROM public.entitlement_reconciliation_jobs WHERE provider=p AND subject=old_subject;
  END IF;
  IF new_subject IS NOT NULL AND u IS NOT NULL THEN
    INSERT INTO public.entitlement_reconciliation_jobs(provider,subject,user_id) VALUES(p,new_subject,u)
      ON CONFLICT(provider,subject) DO UPDATE SET user_id=EXCLUDED.user_id,
        next_attempt_at=now(),lease_token=NULL,lease_expires_at=NULL,attempts=0,last_success_at=NULL,last_failure_at=NULL
      WHERE public.entitlement_reconciliation_jobs.user_id IS DISTINCT FROM EXCLUDED.user_id;
  END IF;
  RETURN NULL;
END;
$$;
REVOKE ALL ON FUNCTION public.sync_entitlement_reconciliation_job() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS reconcile_bound_twitch ON public.twitch_account_bindings;
CREATE TRIGGER reconcile_bound_twitch AFTER INSERT OR UPDATE OR DELETE ON public.twitch_account_bindings
FOR EACH ROW EXECUTE FUNCTION public.sync_entitlement_reconciliation_job();
DROP TRIGGER IF EXISTS reconcile_bound_store ON public.store_subscription_bindings;
CREATE TRIGGER reconcile_bound_store AFTER INSERT OR UPDATE OR DELETE ON public.store_subscription_bindings
FOR EACH ROW EXECUTE FUNCTION public.sync_entitlement_reconciliation_job();
INSERT INTO public.entitlement_reconciliation_jobs(provider,subject,user_id)
  SELECT 'twitch',twitch_user_id,user_id FROM public.twitch_account_bindings ON CONFLICT DO NOTHING;
INSERT INTO public.entitlement_reconciliation_jobs(provider,subject,user_id)
  SELECT 'apple',subscription_key,user_id FROM public.store_subscription_bindings WHERE platform='app_store' AND user_id IS NOT NULL
  ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION public.claim_entitlement_reconciliation(p_providers text[],p_include_sandbox boolean DEFAULT false)
RETURNS SETOF public.entitlement_reconciliation_jobs LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE job public.entitlement_reconciliation_jobs%ROWTYPE;
BEGIN
  SELECT * INTO job FROM public.entitlement_reconciliation_jobs
    WHERE provider=ANY(p_providers) AND next_attempt_at<=clock_timestamp()
      AND (lease_expires_at IS NULL OR lease_expires_at<=clock_timestamp())
      AND (p_include_sandbox OR provider<>'apple' OR subject NOT LIKE 'sandbox:%')
    ORDER BY next_attempt_at,provider,subject FOR UPDATE SKIP LOCKED LIMIT 1;
  IF NOT FOUND THEN RETURN; END IF;
  RETURN QUERY UPDATE public.entitlement_reconciliation_jobs SET lease_token=gen_random_uuid(),
    lease_expires_at=clock_timestamp()+interval '2 minutes', attempts=least(attempts+1,30)
    WHERE provider=job.provider AND subject=job.subject RETURNING *;
END;
$$;
CREATE OR REPLACE FUNCTION public.finish_entitlement_reconciliation(p_provider text,p_subject text,p_lease uuid,p_success boolean)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE changed integer;
BEGIN
  IF p_success IS NULL THEN RAISE EXCEPTION 'Missing result'; END IF;
  UPDATE public.entitlement_reconciliation_jobs SET
    next_attempt_at=clock_timestamp()+CASE WHEN p_success THEN interval '6 hours'
      ELSE make_interval(secs=>least(21600,60*power(2,least(attempts-1,9)))::integer) END,
    last_success_at=CASE WHEN p_success THEN clock_timestamp() ELSE last_success_at END,
    last_failure_at=CASE WHEN NOT p_success THEN clock_timestamp() ELSE last_failure_at END,
    attempts=CASE WHEN p_success THEN 0 ELSE attempts END, lease_token=NULL,lease_expires_at=NULL
    WHERE provider=p_provider AND subject=p_subject AND lease_token=p_lease AND lease_expires_at>clock_timestamp();
  GET DIAGNOSTICS changed=ROW_COUNT;
  RETURN changed=1;
END;
$$;
REVOKE ALL ON FUNCTION public.claim_entitlement_reconciliation(text[],boolean),public.finish_entitlement_reconciliation(text,text,uuid,boolean) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.claim_entitlement_reconciliation(text[],boolean),public.finish_entitlement_reconciliation(text,text,uuid,boolean) TO service_role;

-- Source: 20260912160000_google_token_reconciliation.sql
CREATE TABLE IF NOT EXISTS public.google_play_tokens (
  subscription_key text PRIMARY KEY CHECK(subscription_key ~ '^(production|sandbox):[0-9a-f]{64}$'),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  envelope jsonb NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.google_play_tokens ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.google_play_tokens FROM PUBLIC,anon,authenticated,service_role;
GRANT SELECT ON public.google_play_tokens TO service_role;
ALTER TABLE public.entitlement_reconciliation_jobs DROP CONSTRAINT IF EXISTS entitlement_reconciliation_jobs_provider_check;
ALTER TABLE public.entitlement_reconciliation_jobs ADD CONSTRAINT entitlement_reconciliation_jobs_provider_check CHECK(provider IN ('apple','twitch','google'));

CREATE OR REPLACE FUNCTION public.save_google_play_token(p_subject text,p_user uuid,p_envelope jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('store:google_play',0));
  PERFORM 1 FROM auth.users WHERE id=p_user FOR UPDATE;
  IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM public.store_subscription_bindings WHERE platform='google_play' AND subscription_key=p_subject AND user_id=p_user) THEN
    RAISE EXCEPTION 'Verified Google binding required';
  END IF;
  IF p_envelope IS NULL OR jsonb_typeof(p_envelope)<>'object' OR
    p_envelope->>'version' IS DISTINCT FROM '1' OR
    COALESCE(p_envelope->>'keyId','') !~ '^[a-zA-Z0-9_-]{1,64}$' OR
    COALESCE(p_envelope->>'iv','') !~ '^[A-Za-z0-9+/]{16}$' OR
    COALESCE(p_envelope->>'ciphertext','') !~ '^[A-Za-z0-9+/]+={0,2}$' OR
    length(p_envelope->>'ciphertext') NOT BETWEEN 24 AND 86000 OR
    (p_envelope - ARRAY['version','keyId','iv','ciphertext']) <> '{}'::jsonb THEN
    RAISE EXCEPTION 'Invalid encrypted token';
  END IF;
  INSERT INTO public.google_play_tokens(subscription_key,user_id,envelope) VALUES(p_subject,p_user,p_envelope)
    ON CONFLICT(subscription_key) DO UPDATE SET envelope=EXCLUDED.envelope,updated_at=now()
    WHERE public.google_play_tokens.user_id=EXCLUDED.user_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Token owner changed'; END IF;
  INSERT INTO public.entitlement_reconciliation_jobs(provider,subject,user_id) VALUES('google',p_subject,p_user)
    ON CONFLICT DO NOTHING;
END;
$$;
REVOKE ALL ON FUNCTION public.save_google_play_token(text,uuid,jsonb) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.cleanup_google_play_token()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF OLD.platform='google_play' AND (TG_OP='DELETE' OR NEW.user_id IS DISTINCT FROM OLD.user_id OR NEW.subscription_key IS DISTINCT FROM OLD.subscription_key OR NEW.platform IS DISTINCT FROM OLD.platform) THEN
    DELETE FROM public.google_play_tokens WHERE subscription_key=OLD.subscription_key;
    DELETE FROM public.entitlement_reconciliation_jobs WHERE provider='google' AND subject=OLD.subscription_key;
  END IF;
  RETURN NULL;
END;
$$;
REVOKE ALL ON FUNCTION public.cleanup_google_play_token() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS cleanup_google_token_binding ON public.store_subscription_bindings;
CREATE TRIGGER cleanup_google_token_binding AFTER UPDATE OR DELETE ON public.store_subscription_bindings FOR EACH ROW EXECUTE FUNCTION public.cleanup_google_play_token();

CREATE OR REPLACE FUNCTION public.fulfill_google_purchase_with_token(
  p_user_id uuid,p_platform text,p_transaction_id text,p_product_id text,p_product_type text,p_store_state text,
  p_purchased_at timestamptz,p_expires_at timestamptz,p_is_test boolean,p_metadata jsonb,p_token_envelope jsonb
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;
BEGIN
  IF p_platform IS DISTINCT FROM 'google_play' OR p_product_type IS DISTINCT FROM 'subscription' THEN RAISE EXCEPTION 'Google subscription required'; END IF;
  result:=public.fulfill_verified_store_purchase(p_user_id,p_platform,p_transaction_id,p_product_id,p_product_type,p_store_state,p_purchased_at,p_expires_at,p_is_test,p_metadata);
  PERFORM public.save_google_play_token(p_metadata->>'subscriptionKey',p_user_id,p_token_envelope);
  RETURN result;
END;
$$;
REVOKE ALL ON FUNCTION public.fulfill_google_purchase_with_token(uuid,text,text,text,text,text,timestamptz,timestamptz,boolean,jsonb,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.fulfill_google_purchase_with_token(uuid,text,text,text,text,text,timestamptz,timestamptz,boolean,jsonb,jsonb) TO service_role;

CREATE OR REPLACE FUNCTION public.apply_google_notification_with_token(
  p_message_id text,p_body_hash text,p_observed_at timestamptz,p_snapshot jsonb,p_expected_user uuid,p_token_envelope jsonb
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  PERFORM public.apply_google_play_notification(p_message_id,p_body_hash,p_observed_at,p_snapshot,p_expected_user);
  IF p_snapshot IS NOT NULL AND p_expected_user IS NOT NULL THEN
    PERFORM public.save_google_play_token(p_snapshot->>'subscriptionKey',p_expected_user,p_token_envelope);
  END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.apply_google_notification_with_token(text,text,timestamptz,jsonb,uuid,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.apply_google_notification_with_token(text,text,timestamptz,jsonb,uuid,jsonb) TO service_role;
CREATE OR REPLACE FUNCTION public.claim_entitlement_reconciliation(p_providers text[],p_include_sandbox boolean DEFAULT false)
RETURNS SETOF public.entitlement_reconciliation_jobs LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE job public.entitlement_reconciliation_jobs%ROWTYPE;
BEGIN
  SELECT * INTO job FROM public.entitlement_reconciliation_jobs
    WHERE provider=ANY(p_providers) AND next_attempt_at<=clock_timestamp()
      AND (lease_expires_at IS NULL OR lease_expires_at<=clock_timestamp())
      AND (p_include_sandbox OR provider NOT IN ('apple','google') OR subject NOT LIKE 'sandbox:%')
    AND (provider<>'google' OR EXISTS (
        SELECT 1 FROM public.google_play_tokens t
        JOIN public.store_subscription_bindings b ON b.platform='google_play' AND b.subscription_key=t.subscription_key AND b.user_id=t.user_id
        JOIN public.google_play_subscription_state g ON g.subscription_key=t.subscription_key
        WHERE t.subscription_key=subject AND t.user_id=entitlement_reconciliation_jobs.user_id AND NOT g.superseded
          AND NOT (g.store_state IN ('SUBSCRIPTION_STATE_EXPIRED','SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED') AND g.expires_at IS NOT NULL AND g.expires_at<clock_timestamp()-interval '60 days')
      ))
    ORDER BY next_attempt_at,provider,subject FOR UPDATE SKIP LOCKED LIMIT 1;
  IF NOT FOUND THEN RETURN; END IF;
  RETURN QUERY UPDATE public.entitlement_reconciliation_jobs SET lease_token=gen_random_uuid(),
    lease_expires_at=clock_timestamp()+interval '2 minutes', attempts=least(attempts+1,30)
    WHERE provider=job.provider AND subject=job.subject RETURNING *;
END;
$$;
REVOKE ALL ON FUNCTION public.claim_entitlement_reconciliation(text[],boolean) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.claim_entitlement_reconciliation(text[],boolean) TO service_role;

-- Source: 20260912170000_stripe_reconciliation_jobs.sql
ALTER TABLE public.entitlement_reconciliation_jobs DROP CONSTRAINT IF EXISTS entitlement_reconciliation_jobs_provider_check;
ALTER TABLE public.entitlement_reconciliation_jobs ADD CONSTRAINT entitlement_reconciliation_jobs_provider_check CHECK(provider IN ('apple','twitch','google','stripe'));

CREATE OR REPLACE FUNCTION public.sync_stripe_reconciliation_job()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE owner_id uuid;
BEGIN
  IF TG_OP='DELETE' THEN
    DELETE FROM public.entitlement_reconciliation_jobs WHERE provider='stripe' AND subject=OLD.subscription_id;
    RETURN NULL;
  END IF;
  IF TG_OP='UPDATE' AND OLD.subscription_id IS DISTINCT FROM NEW.subscription_id THEN
    DELETE FROM public.entitlement_reconciliation_jobs WHERE provider='stripe' AND subject=OLD.subscription_id;
  END IF;
  SELECT user_id INTO owner_id FROM public.stripe_customers WHERE customer_id=NEW.customer_id;
  IF owner_id IS NULL THEN
    DELETE FROM public.entitlement_reconciliation_jobs WHERE provider='stripe' AND subject=NEW.subscription_id;
  ELSE
    INSERT INTO public.entitlement_reconciliation_jobs(provider,subject,user_id) VALUES('stripe',NEW.subscription_id,owner_id)
      ON CONFLICT(provider,subject) DO UPDATE SET user_id=EXCLUDED.user_id,next_attempt_at=now(),
        lease_token=NULL,lease_expires_at=NULL,attempts=0,last_success_at=NULL,last_failure_at=NULL
      WHERE public.entitlement_reconciliation_jobs.user_id IS DISTINCT FROM EXCLUDED.user_id;
  END IF;
  RETURN NULL;
END;
$$;
REVOKE ALL ON FUNCTION public.sync_stripe_reconciliation_job() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS reconcile_stripe_subscription ON public.stripe_subscriptions;
CREATE TRIGGER reconcile_stripe_subscription AFTER INSERT OR UPDATE OR DELETE ON public.stripe_subscriptions
FOR EACH ROW EXECUTE FUNCTION public.sync_stripe_reconciliation_job();

CREATE OR REPLACE FUNCTION public.sync_stripe_customer_reconciliation_jobs()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF OLD.user_id IS DISTINCT FROM NEW.user_id THEN
    DELETE FROM public.entitlement_reconciliation_jobs j USING public.stripe_subscriptions s
      WHERE j.provider='stripe' AND j.subject=s.subscription_id AND s.customer_id=NEW.customer_id;
    IF NEW.user_id IS NOT NULL THEN
      INSERT INTO public.entitlement_reconciliation_jobs(provider,subject,user_id)
        SELECT 'stripe',subscription_id,NEW.user_id FROM public.stripe_subscriptions WHERE customer_id=NEW.customer_id
        ON CONFLICT DO NOTHING;
    END IF;
  END IF;
  RETURN NULL;
END;
$$;
REVOKE ALL ON FUNCTION public.sync_stripe_customer_reconciliation_jobs() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS reconcile_stripe_customer ON public.stripe_customers;
CREATE TRIGGER reconcile_stripe_customer AFTER UPDATE OF user_id ON public.stripe_customers
FOR EACH ROW EXECUTE FUNCTION public.sync_stripe_customer_reconciliation_jobs();
INSERT INTO public.entitlement_reconciliation_jobs(provider,subject,user_id)
  SELECT 'stripe',s.subscription_id,c.user_id FROM public.stripe_subscriptions s JOIN public.stripe_customers c USING(customer_id)
  WHERE c.user_id IS NOT NULL ON CONFLICT DO NOTHING;
CREATE OR REPLACE FUNCTION public.claim_entitlement_reconciliation(p_providers text[],p_include_sandbox boolean DEFAULT false)
RETURNS SETOF public.entitlement_reconciliation_jobs LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE job public.entitlement_reconciliation_jobs%ROWTYPE;
BEGIN
  SELECT * INTO job FROM public.entitlement_reconciliation_jobs
    WHERE provider=ANY(p_providers) AND next_attempt_at<=clock_timestamp()
      AND (lease_expires_at IS NULL OR lease_expires_at<=clock_timestamp())
      AND (p_include_sandbox OR provider NOT IN ('apple','google') OR subject NOT LIKE 'sandbox:%')
    AND (provider<>'google' OR EXISTS (
        SELECT 1 FROM public.google_play_tokens t
        JOIN public.store_subscription_bindings b ON b.platform='google_play' AND b.subscription_key=t.subscription_key AND b.user_id=t.user_id
        JOIN public.google_play_subscription_state g ON g.subscription_key=t.subscription_key
        WHERE t.subscription_key=subject AND t.user_id=entitlement_reconciliation_jobs.user_id AND NOT g.superseded
          AND NOT (g.store_state IN ('SUBSCRIPTION_STATE_EXPIRED','SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED') AND g.expires_at IS NOT NULL AND g.expires_at<clock_timestamp()-interval '60 days')
      ))
    AND (provider<>'stripe' OR EXISTS (
      SELECT 1 FROM public.stripe_subscriptions s JOIN public.stripe_customers c USING(customer_id)
      WHERE s.subscription_id=subject AND c.user_id=entitlement_reconciliation_jobs.user_id
        AND s.status NOT IN ('canceled','incomplete_expired')
    ))
    ORDER BY next_attempt_at,provider,subject FOR UPDATE SKIP LOCKED LIMIT 1;
  IF NOT FOUND THEN RETURN; END IF;
  RETURN QUERY UPDATE public.entitlement_reconciliation_jobs SET lease_token=gen_random_uuid(),
    lease_expires_at=clock_timestamp()+interval '2 minutes', attempts=least(attempts+1,30)
    WHERE provider=job.provider AND subject=job.subject RETURNING *;
END;
$$;
REVOKE ALL ON FUNCTION public.claim_entitlement_reconciliation(text[],boolean) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.claim_entitlement_reconciliation(text[],boolean) TO service_role;

COMMIT;
