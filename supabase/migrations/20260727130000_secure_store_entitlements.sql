-- Store entitlements must only be changed after verification by a trusted
-- server. Mobile clients retain read access to their own entitlement state.

DROP POLICY IF EXISTS "Users can insert their own premium status"
  ON public.user_premium_status;
DROP POLICY IF EXISTS "Users can update their own premium status"
  ON public.user_premium_status;
DROP POLICY IF EXISTS "Users can insert their own purchases"
  ON public.user_ai_pack_purchases;
DROP POLICY IF EXISTS "Users can insert their own AI credits"
  ON public.user_ai_credits;
DROP POLICY IF EXISTS "Users can update their own AI credits"
  ON public.user_ai_credits;

REVOKE INSERT, UPDATE, DELETE ON public.user_premium_status
  FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.user_ai_pack_purchases
  FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.user_ai_credits
  FROM anon, authenticated;

REVOKE EXECUTE ON FUNCTION public.add_ai_credits(uuid, integer)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.add_ai_credits(uuid, integer)
  TO service_role;

REVOKE EXECUTE ON FUNCTION public.add_ai_pack_credits(
  uuid, character varying, integer, numeric, character varying
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.add_ai_pack_credits(
  uuid, character varying, integer, numeric, character varying
) TO service_role;

CREATE TABLE IF NOT EXISTS public.store_purchase_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  platform text NOT NULL CHECK (platform IN ('google_play', 'app_store')),
  store_transaction_id text NOT NULL,
  product_id text NOT NULL,
  product_type text NOT NULL CHECK (product_type IN ('subscription', 'consumable')),
  store_state text NOT NULL,
  purchased_at timestamptz,
  expires_at timestamptz,
  is_test boolean NOT NULL DEFAULT false,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  processed_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (platform, store_transaction_id)
);

ALTER TABLE public.store_purchase_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own verified store purchases"
  ON public.store_purchase_events
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

REVOKE ALL ON public.store_purchase_events FROM anon, authenticated;
GRANT SELECT ON public.store_purchase_events TO authenticated;
GRANT ALL ON public.store_purchase_events TO service_role;

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
  v_premium_source text;
BEGIN
  IF p_user_id IS NULL OR p_transaction_id IS NULL OR length(p_transaction_id) < 8 THEN
    RAISE EXCEPTION 'Invalid verified purchase identity';
  END IF;

  IF p_platform NOT IN ('google_play', 'app_store') OR
     p_product_type NOT IN ('subscription', 'consumable') THEN
    RAISE EXCEPTION 'Invalid verified purchase attributes';
  END IF;

  INSERT INTO public.store_purchase_events (
    user_id, platform, store_transaction_id, product_id, product_type,
    store_state, purchased_at, expires_at, is_test, metadata
  ) VALUES (
    p_user_id, p_platform, p_transaction_id, p_product_id, p_product_type,
    p_store_state, p_purchased_at, p_expires_at, p_is_test, p_metadata
  )
  ON CONFLICT (platform, store_transaction_id) DO NOTHING
  RETURNING id INTO v_inserted_id;

  IF v_inserted_id IS NULL THEN
    SELECT * INTO v_existing
    FROM public.store_purchase_events
    WHERE platform = p_platform
      AND store_transaction_id = p_transaction_id;

    IF v_existing.user_id <> p_user_id OR v_existing.product_id <> p_product_id THEN
      RAISE EXCEPTION 'Verified purchase is already bound to another entitlement';
    END IF;

    RETURN jsonb_build_object('success', true, 'already_processed', true);
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
    v_premium_source := CASE p_platform
      WHEN 'google_play' THEN 'google'
      WHEN 'app_store' THEN 'apple'
    END;

    INSERT INTO public.user_premium_status (
      user_id, is_premium, premium_source, premium_since,
      premium_expires_at, updated_at
    ) VALUES (
      p_user_id, true, v_premium_source, COALESCE(p_purchased_at, now()),
      p_expires_at, now()
    )
    ON CONFLICT (user_id) DO UPDATE SET
      is_premium = true,
      premium_source = EXCLUDED.premium_source,
      premium_since = COALESCE(public.user_premium_status.premium_since, EXCLUDED.premium_since),
      premium_expires_at = EXCLUDED.premium_expires_at,
      updated_at = now();
  ELSE
    RAISE EXCEPTION 'Unknown subscription product';
  END IF;

  RETURN jsonb_build_object('success', true, 'already_processed', false);
END;
$$;

REVOKE ALL ON FUNCTION public.fulfill_verified_store_purchase(
  uuid, text, text, text, text, text, timestamptz, timestamptz, boolean, jsonb
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fulfill_verified_store_purchase(
  uuid, text, text, text, text, text, timestamptz, timestamptz, boolean, jsonb
) TO service_role;
