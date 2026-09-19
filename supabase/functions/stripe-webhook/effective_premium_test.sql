DO $$ BEGIN IF current_database()<>'statusxp_effective_test' THEN RAISE EXCEPTION 'Isolated test database required'; END IF; END $$;
CREATE SCHEMA auth;
GRANT USAGE ON SCHEMA public TO authenticated, service_role;
CREATE TABLE auth.users(id uuid PRIMARY KEY);
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
CREATE FUNCTION auth.role() RETURNS text LANGUAGE sql STABLE AS $$ SELECT current_setting('request.jwt.claim.role',true) $$;
CREATE TABLE public.user_ai_credits(user_id uuid PRIMARY KEY,pack_credits integer,updated_at timestamptz);
CREATE TABLE public.user_ai_pack_purchases(user_id uuid,pack_type text,credits_purchased integer,price_paid numeric,platform text);
CREATE TABLE public.user_premium_status(user_id uuid PRIMARY KEY,is_premium boolean,premium_source text,premium_since timestamptz,premium_expires_at timestamptz,updated_at timestamptz);
CREATE TABLE public.user_ai_daily_usage(user_id uuid,usage_date date,uses_today integer,source text,PRIMARY KEY(user_id,usage_date));
CREATE FUNCTION public.add_ai_credits(uuid,integer) RETURNS void LANGUAGE sql AS $$ SELECT $$;
CREATE FUNCTION public.add_ai_pack_credits(uuid,character varying,integer,numeric,character varying) RETURNS void LANGUAGE sql AS $$ SELECT $$;
CREATE FUNCTION public.consume_ai_credit(uuid) RETURNS void LANGUAGE sql AS $$ SELECT $$;
\ir ../../migrations/20260911160000_ai_guide_reservations.sql
\ir ../../migrations/20260911180000_provider_quotas.sql
\ir ../../migrations/20260911200000_stripe_fulfillment.sql
\ir ../../migrations/20260912100000_effective_premium.sql
\ir ../../migrations/20260912100000_effective_premium.sql
BEGIN;
INSERT INTO auth.users VALUES ('00000000-0000-4000-8000-000000000001'),('00000000-0000-4000-8000-000000000002');
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
DO $$
DECLARE u uuid := auth.uid(); result jsonb;
BEGIN
  ASSERT NOT (public.get_my_premium_entitlement()->>'is_premium')::boolean;
  INSERT INTO public.user_premium_status VALUES(u,true,'apple',now(),now()+interval '1 day',now());
  PERFORM public.bind_stripe_customer(u,'cus_effective');
  INSERT INTO public.stripe_subscriptions VALUES('sub_effective','cus_effective','active',now()+interval '30 days',now());
  ASSERT public.get_my_premium_entitlement()->>'premium_source'='apple';
  UPDATE public.user_premium_status SET premium_expires_at=now() WHERE user_id=u;
  result := public.get_my_premium_entitlement();
  ASSERT result->>'premium_source'='stripe';
  ASSERT (result->>'is_premium')::boolean;
  ASSERT result->>'premium_since' IS NULL; -- do not invent a purchase date
  ASSERT public.can_use_ai(u)->>'source'='premium';
  ASSERT public.reserve_ai_guide(u,'00000000-0000-4000-8000-000000000003',repeat('a',64))->>'state'='reserved';
  ASSERT (SELECT source='premium' FROM public.ai_guide_requests WHERE user_id=u);
  -- Four prior syncs exceed the free ceiling but remain within premium quota.
  INSERT INTO public.provider_quota_usage VALUES('sync_psn',u::text,(now() AT TIME ZONE 'UTC')::date,4,NULL);
  ASSERT (public.admit_provider_request(u,'sync_psn',false)->>'allowed')::boolean;
  UPDATE public.stripe_subscriptions SET expires_at=now();
  ASSERT NOT (public.get_my_premium_entitlement()->>'is_premium')::boolean;
  ASSERT public.can_use_ai(u)->>'source'='daily_free';
  ASSERT NOT (public.admit_provider_request(u,'sync_psn',false)->>'allowed')::boolean;
  -- An old Stripe projection cannot override newer cancellation records.
  UPDATE public.user_premium_status SET premium_source='stripe',premium_expires_at=NULL;
  UPDATE public.stripe_subscriptions SET status='canceled',expires_at=now()+interval '30 days';
  ASSERT NOT (public.get_my_premium_entitlement()->>'is_premium')::boolean;
  INSERT INTO public.stripe_subscriptions VALUES('sub_other','cus_effective','active',now()+interval '5 days',now());
  ASSERT (public.get_my_premium_entitlement()->>'is_premium')::boolean;
  -- Existing nonexpiring non-Stripe grants retain their current behavior.
  UPDATE public.user_premium_status SET premium_source='apple';
  ASSERT public.get_my_premium_entitlement()->>'premium_source'='apple';
  -- Legacy Stripe rows without authoritative subscription records survive cutover.
  INSERT INTO public.user_premium_status VALUES('00000000-0000-4000-8000-000000000002',true,'stripe',now(),NULL,now());
  PERFORM set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',true);
  ASSERT (public.get_my_premium_entitlement()->>'is_premium')::boolean;
  UPDATE public.user_premium_status SET is_premium=false WHERE user_id=auth.uid();
  ASSERT NOT (public.get_my_premium_entitlement()->>'is_premium')::boolean;
  ASSERT NOT has_function_privilege('anon','public.get_my_premium_entitlement()','EXECUTE');
  ASSERT has_function_privilege('authenticated','public.get_my_premium_entitlement()','EXECUTE');
  ASSERT NOT has_function_privilege('authenticated','public.effective_premium_entitlement(uuid)','EXECUTE');
END $$;
-- Execute as the real restricted role, without direct source-table access.
SET LOCAL ROLE authenticated;
DO $$ BEGIN
  ASSERT NOT (public.get_my_premium_entitlement()->>'is_premium')::boolean;
  BEGIN
    PERFORM public.can_use_ai('00000000-0000-4000-8000-000000000001');
    RAISE EXCEPTION 'Cross-account access allowed';
  EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM='Unauthorized'; END;
END $$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
DO $$ BEGIN
  ASSERT public.get_my_premium_entitlement()->>'premium_source'='apple';
END $$;
SELECT set_config('request.jwt.claim.sub','',true);
DO $$ BEGIN
  ASSERT NOT (public.get_my_premium_entitlement()->>'is_premium')::boolean;
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claim.role','service_role',true);
SET LOCAL ROLE service_role;
DO $$ BEGIN
  ASSERT public.can_use_ai('00000000-0000-4000-8000-000000000001')->>'source'='premium';
  ASSERT (public.effective_premium_entitlement('00000000-0000-4000-8000-000000000001')->>'is_premium')::boolean;
END $$;
RESET ROLE;
ROLLBACK;
\echo Effective premium fallback, expiry, cancellation, legacy compatibility and identity isolation passed.
