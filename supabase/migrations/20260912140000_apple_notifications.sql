BEGIN;
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


COMMIT;
