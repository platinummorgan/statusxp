BEGIN;
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

COMMIT;
