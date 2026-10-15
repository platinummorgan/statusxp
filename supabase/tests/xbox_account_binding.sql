BEGIN;
INSERT INTO auth.users(id,email,raw_user_meta_data) VALUES
 ('00000000-0000-4000-8000-000000009971','binding-9971@statusxp.invalid','{}'),
 ('00000000-0000-4000-8000-000000009972','binding-9972@statusxp.invalid','{}'),
 ('00000000-0000-4000-8000-000000009973','binding-9973@statusxp.invalid','{}');
INSERT INTO games(platform_id,platform_game_id,name) VALUES(11,'binding-9971','Binding fixture');
SELECT set_config('request.jwt.claims','{"role":"service_role"}',true);
SET LOCAL ROLE service_role;
SELECT public.link_verified_xbox_account('00000000-0000-4000-8000-000000009971','2533274999999971','Original','hash','access','refresh',now()+interval '1 day',100);
INSERT INTO user_progress(user_id,platform_id,platform_game_id,achievements_earned,total_achievements,current_score)
VALUES('00000000-0000-4000-8000-000000009971',11,'binding-9971',1,2,100);
DO $$ BEGIN
 BEGIN PERFORM public.link_verified_xbox_account('00000000-0000-4000-8000-000000009971','2533274999999972','Other','hash','other-access','other-refresh',now()+interval '1 day',500); RAISE EXCEPTION 'Different identity overwrote stats'; EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
 ASSERT (SELECT xbox_xuid='2533274999999971' AND xbox_refresh_token='refresh' FROM profiles WHERE id='00000000-0000-4000-8000-000000009971');
END $$;
SET LOCAL ROLE postgres;
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-000000009971"}',true);
SET LOCAL ROLE authenticated;
UPDATE profiles SET xbox_xuid=NULL,xbox_gamertag=NULL,xbox_access_token=NULL,xbox_refresh_token=NULL,xbox_token_expires_at=NULL,xbox_sync_status='never_synced' WHERE id=auth.uid();
DO $$ BEGIN
 ASSERT (SELECT achievements_earned=1 AND current_score=100 FROM user_progress WHERE user_id=auth.uid());
 ASSERT NOT has_function_privilege('authenticated','public.link_verified_xbox_account(uuid,text,text,text,text,text,timestamptz,bigint)','EXECUTE');
 ASSERT NOT has_function_privilege('authenticated','public.begin_verified_xbox_sync(uuid,text)','EXECUTE');
 ASSERT NOT has_table_privilege('authenticated','public.profiles_private','SELECT');
END $$;
SET LOCAL ROLE postgres;
SELECT set_config('request.jwt.claims','{"role":"service_role"}',true);
SET LOCAL ROLE service_role;
DO $$ BEGIN
 BEGIN PERFORM public.link_verified_xbox_account('00000000-0000-4000-8000-000000009971','2533274999999972','Other','hash','other-access','other-refresh',now()+interval '1 day',500); RAISE EXCEPTION 'Disconnect bypassed retained identity'; EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
 BEGIN UPDATE user_progress SET metadata=jsonb_build_object('xbox_source_xuid','2533274999999971') WHERE user_id='00000000-0000-4000-8000-000000009971'; RAISE EXCEPTION 'Disconnected worker wrote progress'; EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
END $$;
SELECT public.link_verified_xbox_account('00000000-0000-4000-8000-000000009971','2533274999999971','Original','hash','access-2','refresh-2',now()+interval '1 day',100);
-- New imports carry verified identity. Wrong-account and disconnected workers
-- cannot insert records even if an earlier batch check raced with a relink.
INSERT INTO achievements(platform_id,platform_game_id,platform_achievement_id,name,include_in_score) VALUES(11,'binding-9971','1','Binding unlock',true),(11,'binding-9971','2','Binding undated',true);
INSERT INTO user_achievements(user_id,platform_id,platform_game_id,platform_achievement_id,earned_at,xbox_source_xuid) VALUES('00000000-0000-4000-8000-000000009971',11,'binding-9971','1','2025-01-01','2533274999999971');
INSERT INTO user_undated_achievements(user_id,platform_id,platform_game_id,platform_achievement_id,evidence_source,xbox_source_xuid) VALUES('00000000-0000-4000-8000-000000009971',11,'binding-9971','2','xbox_live','2533274999999971');
DO $$ BEGIN
 BEGIN INSERT INTO user_achievements(user_id,platform_id,platform_game_id,platform_achievement_id,earned_at,xbox_source_xuid) VALUES('00000000-0000-4000-8000-000000009971',11,'binding-9971','2','2025-01-01','2533274999999972'); RAISE EXCEPTION 'Wrong-account earned import accepted'; EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
 BEGIN UPDATE user_progress SET metadata=jsonb_build_object('xbox_source_xuid','2533274999999972') WHERE user_id='00000000-0000-4000-8000-000000009971'; RAISE EXCEPTION 'Wrong-account progress accepted'; EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
END $$;
-- An access-token refresh must never erase the existing Microsoft refresh token.
SELECT public.link_verified_xbox_account('00000000-0000-4000-8000-000000009971','2533274999999971','Original','hash','access-3','',now()+interval '1 day',100);
DO $$ DECLARE l bigint; BEGIN
 ASSERT (SELECT xbox_refresh_token='refresh-2' FROM profiles WHERE id='00000000-0000-4000-8000-000000009971');
 l:=public.begin_verified_xbox_sync('00000000-0000-4000-8000-000000009971','2533274999999971');
 ASSERT (SELECT status='pending' FROM xbox_sync_logs WHERE id=l);
 ASSERT (SELECT xbox_sync_status='syncing' FROM profiles WHERE id='00000000-0000-4000-8000-000000009971');
 BEGIN PERFORM public.begin_verified_xbox_sync('00000000-0000-4000-8000-000000009971','2533274999999971'); RAISE EXCEPTION 'Duplicate sync admitted'; EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
 BEGIN UPDATE profiles SET xbox_xuid=NULL WHERE id='00000000-0000-4000-8000-000000009971'; RAISE EXCEPTION 'Active sync identity changed'; EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
 PERFORM request_sync_cancellation('00000000-0000-4000-8000-000000009971','xbox');
 PERFORM finish_platform_sync('00000000-0000-4000-8000-000000009971','xbox',l,'completed');
 ASSERT (SELECT xbox_sync_status='stopped' FROM profiles WHERE id='00000000-0000-4000-8000-000000009971');
END $$;
-- Unknown historical provenance needs review instead of silently mixing a new account.
INSERT INTO user_progress(user_id,platform_id,platform_game_id,achievements_earned,total_achievements)
VALUES('00000000-0000-4000-8000-000000009972',11,'binding-9971',1,2);
DO $$ BEGIN
 BEGIN PERFORM public.link_verified_xbox_account('00000000-0000-4000-8000-000000009972','2533274999999972','Unknown','hash','access','refresh',now()+interval '1 day',100); RAISE EXCEPTION 'Unknown provenance adopted'; EXCEPTION WHEN object_not_in_prerequisite_state THEN NULL; END;
 BEGIN PERFORM public.link_verified_xbox_account('00000000-0000-4000-8000-000000009973','2533274999999971','Duplicate','hash','access','refresh',now()+interval '1 day',100); RAISE EXCEPTION 'Xbox account duplicated'; EXCEPTION WHEN unique_violation THEN NULL; END;
END $$;
SET LOCAL ROLE postgres;
SELECT set_config('request.jwt.claims','{}',true);
DO $$ BEGIN
 ASSERT (SELECT xuid='2533274999999971' FROM statusxp_private.xbox_account_bindings WHERE user_id='00000000-0000-4000-8000-000000009971');
 ASSERT EXISTS(SELECT 1 FROM statusxp_private.xbox_binding_events WHERE user_id='00000000-0000-4000-8000-000000009971' AND event='disconnected');
END $$;
SELECT 'Xbox identity, disconnect/reconnect, credentials and lifecycle checks passed' result;
ROLLBACK;
