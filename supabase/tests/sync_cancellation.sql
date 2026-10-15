BEGIN;
INSERT INTO auth.users(id,email,raw_user_meta_data) VALUES
 ('00000000-0000-4000-8000-000000009952','cancel-9952@statusxp.invalid','{}'),
 ('00000000-0000-4000-8000-000000009953','cancel-9953@statusxp.invalid','{}');
DO $$ DECLARE platform text; logid bigint:=-99520; outcome text; u uuid:='00000000-0000-4000-8000-000000009952'; BEGIN
 FOREACH platform IN ARRAY ARRAY['psn','xbox','steam'] LOOP
  logid:=logid+1;
  EXECUTE format('UPDATE public.profiles_private SET %I=''syncing'' WHERE id=$1',platform||'_sync_status') USING u;
  EXECUTE format('INSERT INTO public.%I(id,user_id,sync_type,status,started_at) VALUES($1,$2,''full'',''syncing'',now())',platform||'_sync_logs') USING logid,u;
  ASSERT public.request_sync_cancellation(u,platform)='cancelling';
  EXECUTE format('UPDATE public.profiles_private SET %I=''syncing'' WHERE id=$1',platform||'_sync_status') USING u;
  EXECUTE format('SELECT %I FROM public.profiles_private WHERE id=$1',platform||'_sync_status') INTO outcome USING u;
  ASSERT outcome='cancelling','Delayed startup must preserve a stop request';
  -- Stop wins even when the worker has just finished its final game.
  ASSERT public.finish_platform_sync(u,platform,logid,'completed',2,7)='cancelled';
  EXECUTE format('SELECT status FROM public.%I WHERE id=$1 AND completed_at IS NOT NULL AND error_message IS NOT NULL AND games_processed=2',platform||'_sync_logs') INTO outcome USING logid;
  ASSERT outcome='cancelled','Cancellation must close the log with timestamp, counters and reason';
  EXECUTE format('SELECT %I FROM public.profiles_private WHERE id=$1 AND %I IS NULL',platform||'_sync_status','last_'||platform||'_sync_at') INTO outcome USING u;
  ASSERT outcome='stopped','Cancellation cannot advance successful sync time';
  ASSERT public.finish_platform_sync(u,platform,logid,'failed',0,0,'late error')='cancelled','Terminal cancellation is immutable';
  BEGIN
   PERFORM public.finish_platform_sync('00000000-0000-4000-8000-000000009953',platform,logid,'cancelled');
   RAISE EXCEPTION 'Wrong owner was accepted';
  EXCEPTION WHEN raise_exception THEN
   IF SQLERRM='Wrong owner was accepted' THEN RAISE; END IF;
  END;
  EXECUTE format('UPDATE public.profiles_private SET %I=''syncing'' WHERE id=$1',platform||'_sync_status') USING u;
  ASSERT public.request_sync_cancellation(u,platform)='stopped','No active log must not leave cancelling stuck';
 END LOOP;
END $$;
-- A late outcome for an older run cannot reset a newer run's profile.
INSERT INTO public.steam_sync_logs(id,user_id,sync_type,status,started_at) VALUES
 (-99510,'00000000-0000-4000-8000-000000009952','full','syncing',now()),
 (-99509,'00000000-0000-4000-8000-000000009952','full','syncing',now());
UPDATE public.profiles_private SET steam_sync_status='syncing' WHERE id='00000000-0000-4000-8000-000000009952';
SELECT public.finish_platform_sync('00000000-0000-4000-8000-000000009952','steam',-99510,'failed');
DO $$ BEGIN
 ASSERT (SELECT steam_sync_status='syncing' FROM profiles_private WHERE id='00000000-0000-4000-8000-000000009952');
 ASSERT NOT has_function_privilege('anon','public.finish_platform_sync(uuid,text,bigint,text,integer,integer,text)','EXECUTE');
 ASSERT NOT has_function_privilege('authenticated','public.request_sync_cancellation(uuid,text)','EXECUTE');
 ASSERT has_function_privilege('service_role','public.finish_platform_sync(uuid,text,bigint,text,integer,integer,text)','EXECUTE');
END $$;
INSERT INTO public.steam_sync_logs(id,user_id,sync_type,status,started_at) VALUES
 (-99508,'00000000-0000-4000-8000-000000009952','full','syncing',now());
SELECT public.finish_platform_sync('00000000-0000-4000-8000-000000009952','steam',-99508,'completed',1,3);
DO $$ BEGIN
 ASSERT (SELECT steam_sync_status='success' AND last_steam_sync_at IS NOT NULL FROM profiles_private WHERE id='00000000-0000-4000-8000-000000009952');
 ASSERT public.request_sync_cancellation('00000000-0000-4000-8000-000000009952','steam')='success','Stop after completion must leave success intact';
END $$;
-- A profile failure must roll back the log update in the same transaction.
INSERT INTO public.steam_sync_logs(id,user_id,sync_type,status,started_at) VALUES
 (-99507,'00000000-0000-4000-8000-000000009953','full','syncing',now());
UPDATE profiles_private SET steam_sync_status='cancelling' WHERE id='00000000-0000-4000-8000-000000009953';
ALTER TABLE profiles_private ADD CONSTRAINT cancellation_atomic_fixture
 CHECK(id<>'00000000-0000-4000-8000-000000009953' OR steam_sync_status<>'stopped');
DO $$ BEGIN
 BEGIN
  PERFORM public.finish_platform_sync('00000000-0000-4000-8000-000000009953','steam',-99507,'cancelled');
  RAISE EXCEPTION 'Expected fixture profile failure';
 EXCEPTION WHEN check_violation THEN NULL;
 END;
 ASSERT (SELECT status='syncing' AND completed_at IS NULL FROM steam_sync_logs WHERE id=-99507),'Log cannot commit when profile update fails';
END $$;
ALTER TABLE profiles_private DROP CONSTRAINT cancellation_atomic_fixture;
ROLLBACK;
