-- Uses the combined Stripe/AI/quota fixture and its database guard.
\ir ../stripe-webhook/effective_premium_test.sql
CREATE TABLE public.profiles(id uuid PRIMARY KEY,twitch_user_id text);
\ir ../../migrations/20260912090000_twitch_event_receipts.sql
\ir ../../migrations/20260912110000_twitch_account_bindings.sql
\ir ../../migrations/20260912110000_twitch_account_bindings.sql
BEGIN;
INSERT INTO auth.users VALUES('00000000-0000-4000-8000-000000000001'),('00000000-0000-4000-8000-000000000002');
INSERT INTO public.profiles(id) SELECT id FROM auth.users;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
DO $$
DECLARE u uuid:=auth.uid(); v uuid:='00000000-0000-4000-8000-000000000002'; t timestamptz:=now();
BEGIN
  -- Unbound observations retain provider state but grant no app account access.
  PERFORM public.apply_twitch_event('unbound','h1',t,'20',true);
  ASSERT NOT (public.get_my_premium_entitlement()->>'is_premium')::boolean;
  BEGIN
    UPDATE public.profiles SET twitch_user_id='20' WHERE id=v;
    RAISE EXCEPTION 'Forged profile allowed';
  EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM='Use verified Twitch linking'; END;
  PERFORM public.bind_verified_twitch_account(u,'20');
  PERFORM public.bind_verified_twitch_account(u,'20');
  ASSERT public.get_my_twitch_binding()='20';
  ASSERT public.get_my_premium_entitlement()->>'premium_source'='twitch';
  BEGIN
    PERFORM public.bind_verified_twitch_account(v,'20');
    RAISE EXCEPTION 'Double binding allowed';
  EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM='Twitch account already linked'; END;
  BEGIN
    PERFORM public.bind_verified_twitch_account(u,'21');
    RAISE EXCEPTION 'Second identity allowed';
  EXCEPTION WHEN unique_violation THEN NULL; END;
  INSERT INTO public.user_premium_status VALUES(u,true,'apple',now(),now()+interval '1 day',now());
  ASSERT public.get_my_premium_entitlement()->>'premium_source'='apple';
  UPDATE public.user_premium_status SET premium_expires_at=now();
  ASSERT public.get_my_premium_entitlement()->>'premium_source'='twitch';
  ASSERT public.can_use_ai(u)->>'source'='premium';
  PERFORM public.apply_twitch_event('ended','h2',t+interval '1 second','20',false);
  ASSERT (public.get_my_premium_entitlement()->>'premium_expires_at')::timestamptz=t+interval '3 days 1 second';
  PERFORM public.apply_twitch_event('stale','h3',t,'20',true);
  ASSERT (public.get_my_premium_entitlement()->>'premium_expires_at')::timestamptz=t+interval '3 days 1 second';
  UPDATE public.twitch_entitlement_state SET expires_at=now();
  UPDATE public.user_premium_status SET is_premium=true,premium_source='twitch',premium_expires_at=NULL;
  ASSERT NOT (public.get_my_premium_entitlement()->>'is_premium')::boolean;
  ASSERT NOT has_function_privilege('authenticated','public.bind_verified_twitch_account(uuid,text)','EXECUTE');
  ASSERT NOT has_table_privilege('authenticated','public.twitch_account_bindings','INSERT');
  ASSERT NOT has_function_privilege('anon','public.disconnect_my_twitch_account()','EXECUTE');
END $$;
SET LOCAL ROLE authenticated;
SELECT public.disconnect_my_twitch_account();
DO $$ BEGIN
  ASSERT public.get_my_twitch_binding() IS NULL;
  ASSERT NOT (public.get_my_premium_entitlement()->>'is_premium')::boolean;
END $$;
RESET ROLE;
DO $$
DECLARE u uuid:=auth.uid(); v uuid:='00000000-0000-4000-8000-000000000002';
BEGIN
  PERFORM public.apply_twitch_event('after-disconnect','h4',now()+interval '2 seconds','20',true);
  ASSERT NOT (public.get_my_premium_entitlement()->>'is_premium')::boolean;
  -- A new OAuth-proven owner may link only after the prior owner disconnects.
  PERFORM public.bind_verified_twitch_account(v,'20');
  ASSERT NOT (public.get_my_premium_entitlement()->>'is_premium')::boolean;
  PERFORM set_config('request.jwt.claim.sub',v::text,true);
  ASSERT public.get_my_premium_entitlement()->>'premium_source'='twitch';
  INSERT INTO public.user_premium_status VALUES(v,true,'stripe',now(),now()+interval '5 days',now());
  PERFORM public.disconnect_my_twitch_account();
  ASSERT public.get_my_premium_entitlement()->>'premium_source'='stripe';
END $$;
ROLLBACK;
\echo Twitch binding, profile forgery, fallback, grace, stale events, disconnect and re-link checks passed.
