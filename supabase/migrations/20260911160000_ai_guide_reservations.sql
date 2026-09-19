-- Apply manually before deploying the guide function/client. Ends legacy
-- unverified purchase compatibility; verified store/webhook fulfillment remains.
BEGIN;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.user_premium_status, public.user_ai_credits,
  public.user_ai_daily_usage FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.add_ai_credits(uuid, integer),
  public.add_ai_pack_credits(uuid, character varying, integer, numeric, character varying),
  public.consume_ai_credit(uuid) FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS public.ai_guide_requests (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  request_id uuid NOT NULL,
  input_hash text NOT NULL,
  state text NOT NULL CHECK (state IN ('pending', 'succeeded', 'failed')),
  source text NOT NULL CHECK (source IN ('premium', 'pack', 'daily_free')),
  usage_date date NOT NULL DEFAULT CURRENT_DATE,
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '2 minutes'),
  guide text CHECK (length(guide) <= 12000),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, request_id)
);
ALTER TABLE public.ai_guide_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ai_guide_requests FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.ai_guide_requests TO service_role;

CREATE OR REPLACE FUNCTION public.finish_ai_guide(
  p_user_id uuid, p_request_id uuid, p_guide text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE r public.ai_guide_requests%ROWTYPE;
BEGIN
  -- All credit transitions lock the same user before touching request/balance rows.
  PERFORM 1 FROM auth.users WHERE id = p_user_id FOR UPDATE;
  SELECT * INTO r FROM public.ai_guide_requests
    WHERE user_id = p_user_id AND request_id = p_request_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Unknown guide request'; END IF;
  IF r.state = 'pending' THEN
    IF p_guide IS NOT NULL AND length(trim(p_guide)) BETWEEN 1 AND 12000
       AND r.expires_at > now() THEN
      UPDATE public.ai_guide_requests SET state = 'succeeded', guide = p_guide
        WHERE user_id = p_user_id AND request_id = p_request_id;
    ELSE
      IF r.source = 'pack' THEN
        UPDATE public.user_ai_credits SET pack_credits = pack_credits + 1, updated_at = now()
          WHERE user_id = p_user_id;
      ELSIF r.source = 'daily_free' THEN
        UPDATE public.user_ai_daily_usage SET uses_today = greatest(0, uses_today - 1)
          WHERE user_id = p_user_id AND usage_date = r.usage_date;
      END IF;
      UPDATE public.ai_guide_requests SET state = 'failed'
        WHERE user_id = p_user_id AND request_id = p_request_id;
    END IF;
  END IF;
  SELECT * INTO r FROM public.ai_guide_requests
    WHERE user_id = p_user_id AND request_id = p_request_id;
  RETURN jsonb_build_object('state', r.state, 'guide', r.guide);
END;
$$;

CREATE OR REPLACE FUNCTION public.reserve_ai_guide(
  p_user_id uuid, p_request_id uuid, p_input_hash text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE r public.ai_guide_requests%ROWTYPE; v_source text; v_used integer; v_pack integer;
BEGIN
  IF p_request_id IS NULL OR p_input_hash IS NULL OR p_input_hash !~ '^[a-f0-9]{64}$' THEN
    RAISE EXCEPTION 'Invalid request';
  END IF;
  PERFORM 1 FROM auth.users WHERE id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Unknown user'; END IF;
  -- Crash recovery is lazy: refund expired work before accepting another request.
  FOR r IN SELECT * FROM public.ai_guide_requests
    WHERE user_id = p_user_id AND state = 'pending' AND expires_at <= now()
  LOOP
    PERFORM public.finish_ai_guide(p_user_id, r.request_id, NULL);
  END LOOP;
  SELECT * INTO r FROM public.ai_guide_requests
    WHERE user_id = p_user_id AND request_id = p_request_id;
  IF FOUND THEN
    IF r.input_hash <> p_input_hash THEN RETURN jsonb_build_object('state', 'conflict'); END IF;
    RETURN jsonb_build_object('state', r.state, 'guide', r.guide);
  END IF;
  IF EXISTS (SELECT 1 FROM public.ai_guide_requests WHERE user_id = p_user_id AND state = 'pending') THEN
    RETURN jsonb_build_object('state', 'busy');
  END IF;
  IF EXISTS (SELECT 1 FROM public.user_premium_status WHERE user_id = p_user_id
      AND is_premium AND (premium_expires_at IS NULL OR premium_expires_at > now())) THEN
    v_source := 'premium';
  ELSE
    SELECT pack_credits INTO v_pack FROM public.user_ai_credits WHERE user_id = p_user_id FOR UPDATE;
    IF coalesce(v_pack, 0) > 0 THEN
      v_source := 'pack';
      UPDATE public.user_ai_credits SET pack_credits = pack_credits - 1, updated_at = now() WHERE user_id = p_user_id;
    ELSE
      SELECT uses_today INTO v_used FROM public.user_ai_daily_usage WHERE user_id = p_user_id AND usage_date = CURRENT_DATE;
      IF coalesce(v_used, 0) >= 3 THEN RETURN jsonb_build_object('state', 'no_credits'); END IF;
      v_source := 'daily_free';
      INSERT INTO public.user_ai_daily_usage(user_id, usage_date, uses_today, source)
        VALUES (p_user_id, CURRENT_DATE, 1, 'daily_free')
        ON CONFLICT (user_id, usage_date) DO UPDATE SET uses_today = coalesce(public.user_ai_daily_usage.uses_today, 0) + 1;
    END IF;
  END IF;
  INSERT INTO public.ai_guide_requests(user_id, request_id, input_hash, state, source)
    VALUES (p_user_id, p_request_id, p_input_hash, 'pending', v_source);
  RETURN jsonb_build_object('state', 'reserved');
END;
$$;

-- Read-only badge uses the same source order and expiry policy as reservation.
CREATE OR REPLACE FUNCTION public.can_use_ai(p_user_id uuid) RETURNS json
LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE v_pack integer; v_used integer;
BEGIN
  IF EXISTS (SELECT 1 FROM public.user_premium_status WHERE user_id = p_user_id
    AND is_premium AND (premium_expires_at IS NULL OR premium_expires_at > now())) THEN
    RETURN json_build_object('can_use', true, 'source', 'premium', 'remaining', -1);
  END IF;
  SELECT pack_credits INTO v_pack FROM public.user_ai_credits WHERE user_id = p_user_id;
  SELECT uses_today INTO v_used FROM public.user_ai_daily_usage WHERE user_id = p_user_id AND usage_date = CURRENT_DATE;
  RETURN json_build_object('can_use', coalesce(v_pack, 0) > 0 OR coalesce(v_used, 0) < 3,
    'source', CASE WHEN coalesce(v_pack, 0) > 0 THEN 'pack' ELSE 'daily_free' END,
    'remaining', CASE WHEN coalesce(v_pack, 0) > 0 THEN v_pack ELSE greatest(0, 3 - coalesce(v_used, 0)) END,
    'pack_credits', coalesce(v_pack, 0), 'daily_free_remaining', greatest(0, 3 - coalesce(v_used, 0)));
END;
$$;
REVOKE ALL ON FUNCTION public.reserve_ai_guide(uuid, uuid, text), public.finish_ai_guide(uuid, uuid, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reserve_ai_guide(uuid, uuid, text), public.finish_ai_guide(uuid, uuid, text) TO service_role;
COMMIT;
