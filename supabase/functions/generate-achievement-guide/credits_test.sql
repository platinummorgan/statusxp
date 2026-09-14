-- Local disposable database only: psql -v ON_ERROR_STOP=1 -d statusxp_ai_test -f ...
DO $$ BEGIN IF current_database() <> 'statusxp_ai_test' THEN RAISE EXCEPTION 'Test database required'; END IF; END $$;
CREATE SCHEMA auth;
CREATE TABLE auth.users(id uuid PRIMARY KEY);
CREATE TABLE public.user_ai_credits(user_id uuid PRIMARY KEY, pack_credits integer DEFAULT 0, updated_at timestamptz);
CREATE TABLE public.user_premium_status(user_id uuid PRIMARY KEY, is_premium boolean, premium_expires_at timestamptz);
CREATE TABLE public.user_ai_daily_usage(user_id uuid, usage_date date, uses_today integer, source text, UNIQUE(user_id, usage_date));
CREATE FUNCTION public.add_ai_credits(uuid, integer) RETURNS void LANGUAGE sql AS 'SELECT';
CREATE FUNCTION public.add_ai_pack_credits(uuid, varchar, integer, numeric, varchar) RETURNS void LANGUAGE sql AS 'SELECT';
CREATE FUNCTION public.consume_ai_credit(uuid) RETURNS json LANGUAGE sql AS 'SELECT ''{}''::json';
\ir ../../migrations/20260911160000_ai_guide_reservations.sql
\ir ../../migrations/20260911160000_ai_guide_reservations.sql
BEGIN;
DO $$
DECLARE u uuid := '00000000-0000-4000-8000-000000000001';
  r uuid := '11111111-1111-4111-8111-111111111111'; h text := repeat('a',64); result jsonb;
BEGIN
  INSERT INTO auth.users VALUES(u);
  INSERT INTO public.user_ai_credits VALUES(u, 1, now());
  result := public.reserve_ai_guide(u,r,h);
  ASSERT result->>'state' = 'reserved';
  ASSERT (SELECT pack_credits = 0 FROM public.user_ai_credits WHERE user_id=u);
  ASSERT public.reserve_ai_guide(u,r,h)->>'state' = 'pending';
  ASSERT public.reserve_ai_guide(u,r,repeat('b',64))->>'state' = 'conflict';
  ASSERT public.reserve_ai_guide(u,gen_random_uuid(),h)->>'state' = 'busy';
  ASSERT public.finish_ai_guide(u,r,'Saved guide')->>'state' = 'succeeded';
  ASSERT public.reserve_ai_guide(u,r,h)->>'guide' = 'Saved guide';
  ASSERT public.finish_ai_guide(u,r,NULL)->>'state' = 'succeeded';
  ASSERT (SELECT pack_credits = 0 FROM public.user_ai_credits WHERE user_id=u);
  -- Daily credits: release once, count exactly three successes, reject fourth.
  r := gen_random_uuid();
  ASSERT public.reserve_ai_guide(u,r,h)->>'state' = 'reserved';
  ASSERT public.finish_ai_guide(u,r,NULL)->>'state' = 'failed';
  PERFORM public.finish_ai_guide(u,r,NULL);
  ASSERT (SELECT uses_today = 0 FROM public.user_ai_daily_usage WHERE user_id=u);
  FOR i IN 1..3 LOOP
    r := gen_random_uuid();
    ASSERT public.reserve_ai_guide(u,r,h)->>'state' = 'reserved';
    PERFORM public.finish_ai_guide(u,r,'Guide');
  END LOOP;
  ASSERT public.reserve_ai_guide(u,gen_random_uuid(),h)->>'state' = 'no_credits';
  ASSERT (public.can_use_ai(u)->>'can_use')::boolean = false;
  -- Expired premium must not bypass quota.
  INSERT INTO public.user_premium_status VALUES(u,true,now()-interval '1 day');
  ASSERT public.reserve_ai_guide(u,gen_random_uuid(),h)->>'state' = 'no_credits';
  UPDATE public.user_premium_status SET premium_expires_at=now()+interval '1 day';
  r := gen_random_uuid();
  ASSERT public.reserve_ai_guide(u,r,h)->>'state' = 'reserved';
  PERFORM public.finish_ai_guide(u,r,'Premium guide');
  UPDATE public.user_premium_status SET is_premium=false;
  -- Crash recovery refunds pack to original source, rejects late completion.
  UPDATE public.user_ai_credits SET pack_credits=1;
  r := gen_random_uuid(); PERFORM public.reserve_ai_guide(u,r,h);
  UPDATE public.ai_guide_requests SET expires_at=now()-interval '1 second' WHERE request_id=r;
  ASSERT public.reserve_ai_guide(u,r,h)->>'state' = 'failed';
  ASSERT public.finish_ai_guide(u,r,'Late output')->>'state' = 'failed';
  ASSERT (SELECT pack_credits = 1 FROM public.user_ai_credits WHERE user_id=u);
  ASSERT NOT has_function_privilege('authenticated','public.reserve_ai_guide(uuid,uuid,text)','execute');
  ASSERT NOT has_function_privilege('anon','public.finish_ai_guide(uuid,uuid,text)','execute');
  ASSERT NOT has_function_privilege('authenticated','public.add_ai_pack_credits(uuid,varchar,integer,numeric,varchar)','execute');
  ASSERT NOT has_function_privilege('authenticated','public.consume_ai_credit(uuid)','execute');
  ASSERT NOT has_table_privilege('authenticated','public.user_premium_status','update');
  ASSERT NOT has_table_privilege('authenticated','public.ai_guide_requests','select');
  ASSERT has_function_privilege('service_role','public.reserve_ai_guide(uuid,uuid,text)','execute');
END;
$$;
ROLLBACK;
