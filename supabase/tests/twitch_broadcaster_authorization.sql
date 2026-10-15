BEGIN;
DO $$ DECLARE f record; BEGIN
 FOR f IN SELECT p.oid FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname IN(
 'begin_twitch_broadcaster_authorization','claim_twitch_broadcaster_authorization','save_verified_twitch_broadcaster_authorization','get_twitch_broadcaster_credentials','claim_twitch_broadcaster_refresh','save_twitch_broadcaster_refresh','release_twitch_broadcaster_refresh') LOOP
  ASSERT NOT has_function_privilege('anon',f.oid,'EXECUTE');
  ASSERT NOT has_function_privilege('authenticated',f.oid,'EXECUTE');
  ASSERT has_function_privilege('service_role',f.oid,'EXECUTE');
 END LOOP;
 ASSERT NOT has_table_privilege('authenticated','statusxp_private.twitch_broadcaster_credentials','SELECT');
 ASSERT NOT has_table_privilege('service_role','statusxp_private.twitch_broadcaster_credentials','SELECT');
END $$;
SELECT set_config('request.jwt.claims','{"role":"service_role"}',true);
SET LOCAL ROLE service_role;
SELECT public.begin_twitch_broadcaster_authorization(repeat('a',64));
DO $$ BEGIN
 ASSERT NOT public.claim_twitch_broadcaster_authorization(repeat('b',64));
 ASSERT public.claim_twitch_broadcaster_authorization(repeat('a',64));
 ASSERT NOT public.claim_twitch_broadcaster_authorization(repeat('a',64));
END $$;
SELECT public.save_verified_twitch_broadcaster_authorization(repeat('a',64),'47221283','fixture-client','fixture-access','fixture-refresh',now()+interval '1 hour');
DO $$ DECLARE r bigint; BEGIN
 ASSERT (public.get_twitch_broadcaster_credentials()->>'refresh_token')='fixture-refresh';
 r:=(public.get_twitch_broadcaster_credentials()->>'revision')::bigint;
 BEGIN PERFORM public.save_verified_twitch_broadcaster_authorization(repeat('a',64),'47221283','fixture-client','other-access','other-refresh',now()+interval '1 hour'); RAISE EXCEPTION 'Reused authorization accepted'; EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
 ASSERT public.claim_twitch_broadcaster_refresh(r,'00000000-0000-4000-8000-000000009951');
 ASSERT NOT public.claim_twitch_broadcaster_refresh(r,'00000000-0000-4000-8000-000000009952');
 ASSERT NOT public.save_twitch_broadcaster_refresh(r,'00000000-0000-4000-8000-000000009952','wrong-access','wrong-refresh',now()+interval '1 hour');
 ASSERT public.save_twitch_broadcaster_refresh(r,'00000000-0000-4000-8000-000000009951','new-access','new-refresh',now()+interval '1 hour');
 ASSERT (public.get_twitch_broadcaster_credentials()->>'refresh_token')='new-refresh';
 ASSERT NOT public.save_twitch_broadcaster_refresh(r,'00000000-0000-4000-8000-000000009951','stale-access','stale-refresh',now()+interval '1 hour');
 ASSERT NOT public.claim_twitch_broadcaster_refresh(r,'00000000-0000-4000-8000-000000009952');
 ASSERT public.claim_twitch_broadcaster_refresh(r+1,'00000000-0000-4000-8000-000000009953');
 PERFORM public.release_twitch_broadcaster_refresh(r+1,'00000000-0000-4000-8000-000000009953');
 ASSERT public.claim_twitch_broadcaster_refresh(r+1,'00000000-0000-4000-8000-000000009954');
END $$;
SET LOCAL ROLE postgres;
UPDATE statusxp_private.twitch_broadcaster_oauth_states SET expires_at=now()-interval '1 minute' WHERE state_hash=repeat('a',64);
SELECT set_config('request.jwt.claims','{"role":"service_role"}',true);
SET LOCAL ROLE service_role;
DO $$ BEGIN ASSERT NOT public.claim_twitch_broadcaster_authorization(repeat('a',64)); END $$;
ROLLBACK;
