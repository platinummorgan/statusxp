BEGIN;
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
COMMIT;
