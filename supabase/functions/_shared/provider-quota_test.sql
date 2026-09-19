DO $$ BEGIN IF current_database() <> 'statusxp_ai_test' THEN RAISE EXCEPTION 'Isolated test database required'; END IF; END $$;
BEGIN;
DO $$
DECLARE u uuid := '00000000-0000-4000-8000-000000000021'; v uuid := '00000000-0000-4000-8000-000000000022'; r jsonb;
BEGIN
  INSERT INTO auth.users VALUES(u),(v);
  ASSERT NOT has_function_privilege('authenticated','public.admit_provider_request(uuid,text,boolean)','execute');
  ASSERT NOT has_table_privilege('authenticated','public.provider_quota_usage','update');
  ASSERT (public.admit_provider_request(u,'sync_psn')->>'allowed')::boolean;
  r := public.admit_provider_request(u,'sync_psn');
  ASSERT NOT (r->>'allowed')::boolean;
  ASSERT (r->>'retry_after')::integer BETWEEN 7190 AND 7200;
  ASSERT (SELECT used=1 FROM public.provider_quota_usage WHERE provider='sync_psn' AND subject=u::text);
  PERFORM set_config('request.jwt.claim.sub',u::text,true);
  ASSERT NOT (public.can_user_sync(u,'psn')->>'can_sync')::boolean;
  -- Premium expiry, own-account checks, global limits and no increment on denial.
  INSERT INTO public.user_premium_status VALUES(v,true,now()-interval '1 day');
  PERFORM public.admit_provider_request(v,'sync_psn');
  ASSERT (public.admit_provider_request(v,'sync_psn')->>'retry_after')::integer>7100;
  UPDATE public.user_premium_status SET premium_expires_at=now()+interval '1 day' WHERE user_id=v;
  ASSERT (public.admit_provider_request(v,'sync_psn')->>'retry_after')::integer BETWEEN 1790 AND 1800;
  UPDATE public.provider_quota_policy SET global_daily=1,free_cooldown=0,premium_cooldown=0 WHERE provider='youtube';
  ASSERT (public.admit_provider_request(u,'youtube')->>'allowed')::boolean;
  ASSERT NOT (public.admit_provider_request(v,'youtube')->>'allowed')::boolean;
  ASSERT (SELECT used=1 FROM public.provider_quota_usage WHERE provider='youtube' AND subject='global');
  -- Free daily limit independent of cooldown, expired premium uses free tier.
  UPDATE public.provider_quota_policy SET free_daily=1,free_cooldown=0 WHERE provider='moderation';
  ASSERT (public.admit_provider_request(u,'moderation')->>'allowed')::boolean;
  ASSERT NOT (public.admit_provider_request(u,'moderation')->>'allowed')::boolean;
  -- Peeking never reserves.
  PERFORM set_config('request.jwt.claim.sub',u::text,true);
  ASSERT (public.can_user_sync(u,'steam')->>'can_sync')::boolean;
  ASSERT NOT EXISTS(SELECT 1 FROM public.provider_quota_usage WHERE provider='sync_steam' AND subject=u::text);
  DELETE FROM auth.users WHERE id=u;
  ASSERT NOT EXISTS(SELECT 1 FROM public.provider_quota_usage WHERE subject=u::text);
END;
$$;
ROLLBACK;
