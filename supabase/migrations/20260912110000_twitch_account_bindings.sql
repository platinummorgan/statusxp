BEGIN;
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
COMMIT;
