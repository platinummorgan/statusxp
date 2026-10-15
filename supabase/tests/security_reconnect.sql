BEGIN;
INSERT INTO auth.users(id,email,raw_user_meta_data) VALUES
 ('00000000-0000-4000-8000-000000009991','reconnect-9991@statusxp.invalid','{}'),
 ('00000000-0000-4000-8000-000000009992','reconnect-9992@statusxp.invalid','{}');
UPDATE public.profiles_private SET psn_account_id='999991',psn_npsso_token='old-npsso',psn_refresh_token='old-psn-refresh',
 xbox_xuid='2533274999999991',xbox_refresh_token='old-xbox-refresh',steam_id='76561198999999991',steam_api_key=repeat('a',32),
 psn_sync_status='success',xbox_sync_status='success',steam_sync_status='success',
 last_psn_sync_at='2020-01-01',last_xbox_sync_at='2020-01-01',last_steam_sync_at='2020-01-01'
WHERE id='00000000-0000-4000-8000-000000009991';
INSERT INTO statusxp_private.security_reconnect_requirements(user_id,platform,account_id,original_credential_hash)
VALUES
 ('00000000-0000-4000-8000-000000009991','psn','999991',encode(extensions.digest('old-npsso','sha256'),'hex')),
 ('00000000-0000-4000-8000-000000009991','xbox','2533274999999991',encode(extensions.digest('old-xbox-refresh','sha256'),'hex')),
 ('00000000-0000-4000-8000-000000009991','steam','76561198999999991',encode(extensions.digest(repeat('a',32),'sha256'),'hex'));
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-000000009992"}',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN ASSERT (SELECT count(*) FROM public.activate_security_reconnect())=0; END $$;
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-000000009991"}',true);
DO $$ BEGIN
 ASSERT (SELECT count(*) FROM public.activate_security_reconnect())=3;
 ASSERT (SELECT bool_and(NOT reset_reported AND NOT sync_active) FROM public.activate_security_reconnect());
 ASSERT NOT (SELECT has_table_privilege('authenticated',c.oid,'SELECT') FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE c.relname='security_reconnect_requirements' AND n.nspname='statusxp_private');
 ASSERT NOT has_function_privilege('authenticated','public.complete_verified_security_reconnect(uuid,text,text,text)','EXECUTE');
 ASSERT NOT has_function_privilege('anon','public.activate_security_reconnect()','EXECUTE');
 ASSERT (SELECT psn_npsso_token IS NULL AND xbox_refresh_token IS NULL AND steam_api_key IS NULL FROM profiles WHERE id=auth.uid());
END $$;
SET LOCAL ROLE postgres;
SELECT set_config('request.jwt.claims','{"role":"service_role"}',true);
SET LOCAL ROLE service_role;
DO $$ DECLARE uid uuid:='00000000-0000-4000-8000-000000009991'; BEGIN
 BEGIN PERFORM public.begin_verified_platform_sync(uid,'psn','999991'); RAISE EXCEPTION 'Pending reconnect started PSN'; EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
 BEGIN PERFORM public.begin_verified_platform_sync(uid,'steam','76561198999999991'); RAISE EXCEPTION 'Pending reconnect started Steam'; EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
 BEGIN PERFORM public.begin_verified_xbox_sync(uid,'2533274999999991'); RAISE EXCEPTION 'Pending reconnect started Xbox'; EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
 BEGIN PERFORM public.complete_verified_security_reconnect(uid,'psn','999991',encode(extensions.digest('fresh-npsso','sha256'),'hex')); RAISE EXCEPTION 'No reset confirmation accepted'; EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
 BEGIN UPDATE profiles SET psn_account_id='other' WHERE id=uid; RAISE EXCEPTION 'Different PSN identity accepted'; EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
 BEGIN UPDATE profiles SET steam_id='76561198999999992' WHERE id=uid; RAISE EXCEPTION 'Different Steam identity accepted'; EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
END $$;
SET LOCAL ROLE postgres;
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-000000009991"}',true);
SET LOCAL ROLE authenticated;
SELECT public.report_security_provider_reset('psn'),public.report_security_provider_reset('xbox'),public.report_security_provider_reset('steam');
-- Re-entering a Steam key with different casing is not a replacement.
UPDATE profiles SET steam_id='76561198999999991',steam_api_key=repeat('A',32) WHERE id=auth.uid();
SET LOCAL ROLE postgres;
SELECT set_config('request.jwt.claims','{"role":"service_role"}',true);
SET LOCAL ROLE service_role;
DO $$ DECLARE uid uuid:='00000000-0000-4000-8000-000000009991'; BEGIN
 BEGIN PERFORM public.complete_verified_security_reconnect(uid,'steam','76561198999999991',encode(extensions.digest(repeat('a',32),'sha256'),'hex')); RAISE EXCEPTION 'Reused key accepted'; EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
 UPDATE profiles SET psn_refresh_token='routine-refresh-only',xbox_refresh_token='routine-refresh-only' WHERE id=uid;
 BEGIN PERFORM public.complete_verified_security_reconnect(uid,'psn','999991',encode(extensions.digest('fresh-npsso','sha256'),'hex')); RAISE EXCEPTION 'Routine PSN refresh accepted'; EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
END $$;
SET LOCAL ROLE postgres;
DO $$ BEGIN ASSERT (SELECT count(*) FROM statusxp_private.security_reconnect_requirements WHERE user_id='00000000-0000-4000-8000-000000009991' AND reconnected_at IS NULL)=3; END $$;
UPDATE profiles_private SET psn_npsso_token='fresh-npsso',xbox_refresh_token='fresh-xbox-grant',steam_api_key=repeat('b',32) WHERE id='00000000-0000-4000-8000-000000009991';
SELECT set_config('request.jwt.claims','{"role":"service_role"}',true);
SET LOCAL ROLE service_role;
DO $$ DECLARE uid uuid:='00000000-0000-4000-8000-000000009991'; l bigint; BEGIN
 BEGIN PERFORM public.complete_verified_security_reconnect(uid,'steam','76561198999999991',encode(extensions.digest(repeat('a',32),'sha256'),'hex')); RAISE EXCEPTION 'Stale verification cleared newer key'; EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
 ASSERT public.complete_verified_security_reconnect(uid,'psn','999991',encode(extensions.digest('fresh-npsso','sha256'),'hex'));
 ASSERT public.complete_verified_security_reconnect(uid,'xbox','2533274999999991',encode(extensions.digest('fresh-xbox-grant','sha256'),'hex'));
 ASSERT public.complete_verified_security_reconnect(uid,'steam','76561198999999991',encode(extensions.digest(repeat('b',32),'sha256'),'hex'));
 ASSERT NOT public.complete_verified_security_reconnect(uid,'steam','76561198999999991',encode(extensions.digest(repeat('b',32),'sha256'),'hex'));
 l:=public.begin_verified_platform_sync(uid,'steam','76561198999999991');
 ASSERT public.finish_platform_sync(uid,'steam',l,'failed',0,0,'Fixture failure')='failed';
 ASSERT (SELECT last_psn_sync_at='2020-01-01' AND last_xbox_sync_at='2020-01-01' AND last_steam_sync_at='2020-01-01' FROM profiles WHERE id=uid);
END $$;
SET LOCAL ROLE postgres;
DO $$ BEGIN ASSERT NOT EXISTS(SELECT 1 FROM statusxp_private.security_reconnect_requirements WHERE user_id='00000000-0000-4000-8000-000000009991' AND provider_revocation_verified_at IS NOT NULL); END $$;
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-000000009991"}',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN ASSERT (SELECT count(*) FROM public.activate_security_reconnect())=0; END $$;
ROLLBACK;
