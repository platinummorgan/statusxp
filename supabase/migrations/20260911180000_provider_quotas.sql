BEGIN;
-- Application ceilings, not claims about upstream provider allowances.
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
ON CONFLICT DO NOTHING;
CREATE TABLE IF NOT EXISTS public.provider_quota_usage (
  provider text NOT NULL REFERENCES public.provider_quota_policy(provider),
  subject text NOT NULL,
  day date NOT NULL,
  used integer NOT NULL DEFAULT 0,
  last_used timestamptz,
  PRIMARY KEY(provider, subject, day)
);
ALTER TABLE public.provider_quota_policy ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.provider_quota_usage ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.provider_quota_policy, public.provider_quota_usage FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.provider_quota_policy, public.provider_quota_usage TO service_role;

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
  SELECT EXISTS (SELECT 1 FROM public.user_premium_status WHERE user_id=p_user_id
    AND is_premium AND (premium_expires_at IS NULL OR premium_expires_at>v_now)) INTO v_premium;
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
CREATE OR REPLACE FUNCTION public.can_user_sync(p_user_id uuid, p_platform text) RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE r jsonb;
BEGIN
  IF auth.uid() IS DISTINCT FROM p_user_id AND coalesce(auth.role(),'') <> 'service_role' THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  r := public.admit_provider_request(p_user_id,'sync_' || lower(p_platform),false);
  RETURN json_build_object('can_sync',(r->>'allowed')::boolean,
    'reason',CASE WHEN (r->>'allowed')::boolean THEN 'Ready to sync' ELSE 'Sync limit reached. Please try again later.' END,
    'wait_seconds',(r->>'retry_after')::integer);
END;
$$;
REVOKE ALL ON FUNCTION public.can_user_sync(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_user_sync(uuid,text) TO authenticated, service_role;
CREATE OR REPLACE FUNCTION public.remove_user_provider_usage() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  DELETE FROM public.provider_quota_usage WHERE subject=OLD.id::text;
  RETURN OLD;
END;
$$;
REVOKE ALL ON FUNCTION public.remove_user_provider_usage() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS remove_user_provider_usage ON auth.users;
CREATE TRIGGER remove_user_provider_usage AFTER DELETE ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.remove_user_provider_usage();
COMMIT;
