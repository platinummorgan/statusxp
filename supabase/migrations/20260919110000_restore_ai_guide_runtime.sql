-- Restore the database contract used by the JSON achievement-guide client.
-- Earlier September migrations were applied selectively to production, which
-- left the guide function on its legacy streaming contract without the
-- reservation and provider-quota functions required by the current client.
BEGIN;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON public.user_premium_status, public.user_ai_credits,
     public.user_ai_daily_usage
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.add_ai_credits(uuid, integer),
  public.add_ai_pack_credits(
    uuid, character varying, integer, numeric, character varying
  ),
  public.consume_ai_credit(uuid)
  FROM PUBLIC, anon, authenticated;

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

CREATE TABLE IF NOT EXISTS public.provider_quota_policy (
  provider text PRIMARY KEY,
  free_daily integer NOT NULL CHECK (free_daily > 0),
  premium_daily integer NOT NULL CHECK (premium_daily > 0),
  global_daily integer NOT NULL CHECK (global_daily > 0),
  free_cooldown integer NOT NULL CHECK (free_cooldown >= 0),
  premium_cooldown integer NOT NULL CHECK (premium_cooldown >= 0)
);
INSERT INTO public.provider_quota_policy VALUES
  ('youtube', 10, 30, 90, 3, 3),
  ('moderation', 100, 200, 5000, 1, 1),
  ('ai', 100, 100, 1000, 5, 5),
  ('sync_psn', 3, 12, 10000, 7200, 1800),
  ('sync_xbox', 24, 96, 10000, 3600, 900),
  ('sync_steam', 24, 96, 10000, 3600, 900)
ON CONFLICT (provider) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.provider_quota_usage (
  provider text NOT NULL REFERENCES public.provider_quota_policy(provider),
  subject text NOT NULL,
  day date NOT NULL,
  used integer NOT NULL DEFAULT 0,
  last_used timestamptz,
  PRIMARY KEY (provider, subject, day)
);
ALTER TABLE public.provider_quota_policy ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.provider_quota_usage ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.provider_quota_policy, public.provider_quota_usage
  FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.provider_quota_policy, public.provider_quota_usage
  TO service_role;

CREATE OR REPLACE FUNCTION public.finish_ai_guide(
  p_user_id uuid, p_request_id uuid, p_guide text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE r public.ai_guide_requests%ROWTYPE;
BEGIN
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
        UPDATE public.user_ai_credits
          SET pack_credits = pack_credits + 1, updated_at = now()
          WHERE user_id = p_user_id;
      ELSIF r.source = 'daily_free' THEN
        UPDATE public.user_ai_daily_usage
          SET uses_today = greatest(0, uses_today - 1)
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
DECLARE
  r public.ai_guide_requests%ROWTYPE;
  v_source text;
  v_used integer;
  v_pack integer;
BEGIN
  IF p_request_id IS NULL OR p_input_hash IS NULL
     OR p_input_hash !~ '^[a-f0-9]{64}$' THEN
    RAISE EXCEPTION 'Invalid request';
  END IF;
  PERFORM 1 FROM auth.users WHERE id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Unknown user'; END IF;
  FOR r IN SELECT * FROM public.ai_guide_requests
    WHERE user_id = p_user_id AND state = 'pending' AND expires_at <= now()
  LOOP
    PERFORM public.finish_ai_guide(p_user_id, r.request_id, NULL);
  END LOOP;
  SELECT * INTO r FROM public.ai_guide_requests
    WHERE user_id = p_user_id AND request_id = p_request_id;
  IF FOUND THEN
    IF r.input_hash <> p_input_hash THEN
      RETURN jsonb_build_object('state', 'conflict');
    END IF;
    RETURN jsonb_build_object('state', r.state, 'guide', r.guide);
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.ai_guide_requests
    WHERE user_id = p_user_id AND state = 'pending'
  ) THEN
    RETURN jsonb_build_object('state', 'busy');
  END IF;
  IF (public.effective_premium_entitlement(p_user_id)->>'is_premium')::boolean THEN
    v_source := 'premium';
  ELSE
    SELECT pack_credits INTO v_pack FROM public.user_ai_credits
      WHERE user_id = p_user_id FOR UPDATE;
    IF coalesce(v_pack, 0) > 0 THEN
      v_source := 'pack';
      UPDATE public.user_ai_credits
        SET pack_credits = pack_credits - 1, updated_at = now()
        WHERE user_id = p_user_id;
    ELSE
      SELECT uses_today INTO v_used FROM public.user_ai_daily_usage
        WHERE user_id = p_user_id AND usage_date = CURRENT_DATE;
      IF coalesce(v_used, 0) >= 3 THEN
        RETURN jsonb_build_object('state', 'no_credits');
      END IF;
      v_source := 'daily_free';
      INSERT INTO public.user_ai_daily_usage(
        user_id, usage_date, uses_today, source
      ) VALUES (p_user_id, CURRENT_DATE, 1, 'daily_free')
      ON CONFLICT (user_id, usage_date) DO UPDATE
        SET uses_today = coalesce(public.user_ai_daily_usage.uses_today, 0) + 1;
    END IF;
  END IF;
  INSERT INTO public.ai_guide_requests(
    user_id, request_id, input_hash, state, source
  ) VALUES (p_user_id, p_request_id, p_input_hash, 'pending', v_source);
  RETURN jsonb_build_object('state', 'reserved');
END;
$$;

CREATE OR REPLACE FUNCTION public.can_use_ai(p_user_id uuid) RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_pack integer; v_used integer; v_daily integer;
BEGIN
  IF auth.uid() IS DISTINCT FROM p_user_id
     AND coalesce(auth.role(), '') <> 'service_role' THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  IF (public.effective_premium_entitlement(p_user_id)->>'is_premium')::boolean THEN
    RETURN json_build_object(
      'can_use', true, 'source', 'premium', 'remaining', -1,
      'pack_credits', 0, 'daily_free', 0, 'daily_free_remaining', 0
    );
  END IF;
  SELECT pack_credits INTO v_pack FROM public.user_ai_credits
    WHERE user_id = p_user_id;
  SELECT uses_today INTO v_used FROM public.user_ai_daily_usage
    WHERE user_id = p_user_id AND usage_date = CURRENT_DATE;
  v_daily := greatest(0, 3 - coalesce(v_used, 0));
  RETURN json_build_object(
    'can_use', coalesce(v_pack, 0) > 0 OR v_daily > 0,
    'source', CASE WHEN coalesce(v_pack, 0) > 0
      THEN 'pack' ELSE 'daily_free' END,
    'remaining', CASE WHEN coalesce(v_pack, 0) > 0 THEN v_pack ELSE v_daily END,
    'pack_credits', coalesce(v_pack, 0),
    'daily_free', v_daily,
    'daily_free_remaining', v_daily
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admit_provider_request(
  p_user_id uuid, p_provider text, p_consume boolean DEFAULT true
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  p public.provider_quota_policy%ROWTYPE;
  v_limit integer;
  v_cooldown integer;
  v_premium boolean;
  v_used integer;
  v_global integer;
  v_last timestamptz;
  v_now timestamptz := clock_timestamp();
  v_day date := (clock_timestamp() AT TIME ZONE 'UTC')::date;
  v_wait integer;
BEGIN
  SELECT * INTO p FROM public.provider_quota_policy
    WHERE provider = p_provider FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Unknown quota policy'; END IF;
  v_now := clock_timestamp();
  v_day := (v_now AT TIME ZONE 'UTC')::date;
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_user_id) THEN
    RAISE EXCEPTION 'Unknown user';
  END IF;
  v_premium := (
    public.effective_premium_entitlement(p_user_id)->>'is_premium'
  )::boolean;
  v_limit := CASE WHEN v_premium THEN p.premium_daily ELSE p.free_daily END;
  v_cooldown := CASE WHEN v_premium
    THEN p.premium_cooldown ELSE p.free_cooldown END;
  SELECT used INTO v_used FROM public.provider_quota_usage
    WHERE provider = p_provider AND subject = p_user_id::text AND day = v_day;
  SELECT used INTO v_global FROM public.provider_quota_usage
    WHERE provider = p_provider AND subject = 'global' AND day = v_day;
  SELECT max(last_used) INTO v_last FROM public.provider_quota_usage
    WHERE provider = p_provider AND subject = p_user_id::text AND day >= v_day - 1;
  v_wait := greatest(0, ceil(extract(epoch FROM
    v_last + make_interval(secs => v_cooldown) - v_now))::integer);
  IF coalesce(v_used, 0) >= v_limit OR coalesce(v_global, 0) >= p.global_daily THEN
    v_wait := greatest(1, ceil(extract(epoch FROM
      ((v_day + 1)::timestamp AT TIME ZONE 'UTC') - v_now))::integer);
  END IF;
  IF v_wait > 0 THEN
    RETURN jsonb_build_object('allowed', false, 'retry_after', v_wait);
  END IF;
  IF NOT p_consume THEN
    RETURN jsonb_build_object('allowed', true, 'retry_after', 0);
  END IF;
  DELETE FROM public.provider_quota_usage
    WHERE provider = p_provider AND day < v_day - 2;
  INSERT INTO public.provider_quota_usage(
    provider, subject, day, used, last_used
  ) VALUES
    (p_provider, p_user_id::text, v_day, 1, v_now),
    (p_provider, 'global', v_day, 1, v_now)
  ON CONFLICT (provider, subject, day) DO UPDATE
    SET used = public.provider_quota_usage.used + 1, last_used = v_now;
  RETURN jsonb_build_object('allowed', true, 'retry_after', 0);
END;
$$;

REVOKE ALL ON FUNCTION public.reserve_ai_guide(uuid, uuid, text),
  public.finish_ai_guide(uuid, uuid, text),
  public.admit_provider_request(uuid, text, boolean)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reserve_ai_guide(uuid, uuid, text),
  public.finish_ai_guide(uuid, uuid, text),
  public.admit_provider_request(uuid, text, boolean)
  TO service_role;
REVOKE ALL ON FUNCTION public.can_use_ai(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.can_use_ai(uuid) TO authenticated, service_role;

COMMIT;
