BEGIN;
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

COMMIT;
