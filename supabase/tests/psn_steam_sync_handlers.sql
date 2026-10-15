BEGIN;
INSERT INTO auth.users(id,email,raw_user_meta_data) VALUES
 ('00000000-0000-4000-8000-000000009981','platform-9981@statusxp.invalid','{}'),
 ('00000000-0000-4000-8000-000000009982','platform-9982@statusxp.invalid','{}');
SELECT set_config('request.jwt.claims','{"role":"service_role"}',true);
SET LOCAL ROLE service_role;
UPDATE profiles SET psn_account_id='9999981',psn_refresh_token='fixture-refresh',steam_id='76561198999999981',
 psn_sync_status='never_synced',steam_sync_status='never_synced' WHERE id='00000000-0000-4000-8000-000000009981';
DO $$ DECLARE l bigint; platform text; account text; uid uuid:='00000000-0000-4000-8000-000000009981'; BEGIN
 FOREACH platform IN ARRAY ARRAY['psn','steam'] LOOP
  account:=CASE platform WHEN 'psn' THEN '9999981' ELSE '76561198999999981' END;
  BEGIN PERFORM begin_verified_platform_sync(uid,platform,'wrong-account'); RAISE EXCEPTION 'Wrong connection accepted'; EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
  l:=begin_verified_platform_sync(uid,platform,account);
  BEGIN PERFORM begin_verified_platform_sync(uid,platform,account); RAISE EXCEPTION 'Duplicate start accepted'; EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
  IF platform='psn' THEN
   BEGIN UPDATE profiles SET psn_account_id=NULL WHERE id=uid; RAISE EXCEPTION 'Active disconnect accepted'; EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
  ELSE
   BEGIN UPDATE profiles SET steam_id=NULL WHERE id=uid; RAISE EXCEPTION 'Active disconnect accepted'; EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
  END IF;
  ASSERT request_sync_cancellation(uid,platform)='cancelling';
  BEGIN PERFORM begin_verified_platform_sync(uid,platform,account); RAISE EXCEPTION 'Cancelling start accepted'; EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
  ASSERT finish_platform_sync(uid,platform,l,'completed',0,0)='cancelled';
  l:=begin_verified_platform_sync(uid,platform,account);
  ASSERT finish_platform_sync(uid,platform,l,'failed',0,0,'Fixture failure')='failed';
  IF platform='psn' THEN ASSERT (SELECT last_psn_sync_at IS NULL AND psn_sync_status='error' FROM profiles WHERE id=uid);
  ELSE ASSERT (SELECT last_steam_sync_at IS NULL AND steam_sync_status='error' FROM profiles WHERE id=uid); END IF;
 END LOOP;
 BEGIN UPDATE profiles SET psn_account_id='9999981' WHERE id='00000000-0000-4000-8000-000000009982'; RAISE EXCEPTION 'Duplicate PSN identity accepted'; EXCEPTION WHEN unique_violation THEN NULL; END;
END $$;
DO $$ BEGIN
 ASSERT NOT has_function_privilege('authenticated','public.begin_verified_platform_sync(uuid,text,text)','EXECUTE');
 ASSERT NOT has_function_privilege('anon','public.begin_verified_platform_sync(uuid,text,text)','EXECUTE');
END $$;
ROLLBACK;
