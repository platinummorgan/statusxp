BEGIN;
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

-- Keep feature admission and client display on the same effective entitlement.
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
  IF (public.effective_premium_entitlement(p_user_id)->>'is_premium')::boolean THEN
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
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_pack integer; v_used integer;
BEGIN
  IF auth.uid() IS DISTINCT FROM p_user_id AND coalesce(auth.role(),'') <> 'service_role' THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  IF (public.effective_premium_entitlement(p_user_id)->>'is_premium')::boolean THEN
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
CREATE OR REPLACE FUNCTION public.admit_provider_request(p_user_id uuid, p_provider text, p_consume boolean DEFAULT true)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE p public.provider_quota_policy%ROWTYPE; v_limit integer; v_cooldown integer;
  v_premium boolean; v_used integer; v_global integer; v_last timestamptz;
  v_now timestamptz := clock_timestamp(); v_day date := (clock_timestamp() AT TIME ZONE 'UTC')::date;
  v_wait integer;
BEGIN
  -- One short lock per provider serializes both global and per-user checks.
  SELECT * INTO p FROM public.provider_quota_policy WHERE provider=p_provider FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Unknown quota policy'; END IF;
  v_now := clock_timestamp(); v_day := (v_now AT TIME ZONE 'UTC')::date;
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id=p_user_id) THEN RAISE EXCEPTION 'Unknown user'; END IF;
  v_premium := (public.effective_premium_entitlement(p_user_id)->>'is_premium')::boolean;
  v_limit := CASE WHEN v_premium THEN p.premium_daily ELSE p.free_daily END;
  v_cooldown := CASE WHEN v_premium THEN p.premium_cooldown ELSE p.free_cooldown END;
  SELECT used INTO v_used FROM public.provider_quota_usage WHERE provider=p_provider AND subject=p_user_id::text AND day=v_day;
  SELECT used INTO v_global FROM public.provider_quota_usage WHERE provider=p_provider AND subject='global' AND day=v_day;
  SELECT max(last_used) INTO v_last FROM public.provider_quota_usage
    WHERE provider=p_provider AND subject=p_user_id::text AND day>=v_day-1;
  v_wait := greatest(0, ceil(extract(epoch FROM v_last + make_interval(secs=>v_cooldown)-v_now))::integer);
  IF coalesce(v_used,0)>=v_limit OR coalesce(v_global,0)>=p.global_daily THEN
    v_wait := greatest(1, ceil(extract(epoch FROM ((v_day+1)::timestamp AT TIME ZONE 'UTC')-v_now))::integer);
  END IF;
  IF v_wait>0 THEN RETURN jsonb_build_object('allowed',false,'retry_after',v_wait); END IF;
  IF NOT p_consume THEN RETURN jsonb_build_object('allowed',true,'retry_after',0); END IF;
  DELETE FROM public.provider_quota_usage WHERE provider=p_provider AND day<v_day-2;
  INSERT INTO public.provider_quota_usage(provider,subject,day,used,last_used)
    VALUES(p_provider,p_user_id::text,v_day,1,v_now),(p_provider,'global',v_day,1,v_now)
    ON CONFLICT(provider,subject,day) DO UPDATE SET used=public.provider_quota_usage.used+1,last_used=v_now;
  RETURN jsonb_build_object('allowed',true,'retry_after',0);
END;
$$;
REVOKE ALL ON FUNCTION public.admit_provider_request(uuid,text,boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admit_provider_request(uuid,text,boolean) TO service_role;
REVOKE ALL ON FUNCTION public.reserve_ai_guide(uuid,uuid,text), public.can_use_ai(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.reserve_ai_guide(uuid,uuid,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.can_use_ai(uuid) TO authenticated,service_role;
COMMIT;
