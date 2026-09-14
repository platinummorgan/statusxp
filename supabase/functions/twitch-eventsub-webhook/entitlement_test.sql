DO $$ BEGIN IF current_database()<>'statusxp_twitch_test' THEN RAISE EXCEPTION 'Isolated database required'; END IF; END $$;
CREATE SCHEMA auth;
CREATE TABLE auth.users(id uuid PRIMARY KEY);
CREATE TABLE public.profiles(id uuid PRIMARY KEY,twitch_user_id text);
CREATE TABLE public.user_premium_status(user_id uuid PRIMARY KEY,is_premium boolean,premium_source text,premium_expires_at timestamptz,updated_at timestamptz);
\ir ../../migrations/20260912090000_twitch_event_receipts.sql
\ir ../../migrations/20260912090000_twitch_event_receipts.sql
BEGIN;
DO $$
DECLARE u uuid:='00000000-0000-4000-8000-000000000001'; t timestamptz:=now(); expiry timestamptz;
BEGIN
  INSERT INTO auth.users VALUES(u);INSERT INTO public.profiles VALUES(u,'20');
  PERFORM public.apply_twitch_event('first','hash1',t,'20',true);
  SELECT premium_expires_at INTO expiry FROM public.user_premium_status WHERE user_id=u;
  ASSERT expiry=t+interval '33 days';
  PERFORM public.apply_twitch_event('first','hash1',t,'20',true);
  PERFORM public.apply_twitch_event('second','hash2',t,'20',true);
  ASSERT (SELECT premium_expires_at=expiry FROM public.user_premium_status WHERE user_id=u);
  PERFORM public.apply_twitch_event('end','hash3',t+interval '1 second','20',false);
  ASSERT (SELECT premium_expires_at=t+interval '3 days 1 second' FROM public.user_premium_status WHERE user_id=u);
  PERFORM public.apply_twitch_event('older','hash4',t,'20',true);
  PERFORM public.apply_twitch_event('tied','hash5',t+interval '1 second','20',true);
  ASSERT (SELECT NOT active FROM public.twitch_entitlement_state WHERE twitch_user_id='20');
  UPDATE public.user_premium_status SET premium_source='stripe',premium_expires_at=t+interval '40 days';
  PERFORM public.apply_twitch_event('renew','hash6',t+interval '2 seconds','20',true);
  ASSERT (SELECT premium_source='stripe' AND premium_expires_at=t+interval '40 days' FROM public.user_premium_status WHERE user_id=u);
  BEGIN PERFORM public.apply_twitch_event('first','differenthash',t,'20',true);RAISE EXCEPTION 'Conflict accepted';
    EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM='Message conflict';END;
  ASSERT NOT has_function_privilege('authenticated','public.apply_twitch_event(text,text,timestamptz,text,boolean)','execute');
  ASSERT NOT has_table_privilege('anon','public.twitch_event_receipts','select');
END;
$$;
ROLLBACK;
