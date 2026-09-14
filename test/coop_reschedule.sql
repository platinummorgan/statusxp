\set ON_ERROR_STOP on
DO $$ BEGIN IF current_database() <> 'statusxp_coop_sessions_test' THEN RAISE EXCEPTION 'Use isolated co-op fixture'; END IF; END $$;
\ir ../supabase/migrations/20260913200000_coop_rescheduling.sql
\ir ../supabase/migrations/20260913200000_coop_rescheduling.sql
BEGIN;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
INSERT INTO public.trophy_help_requests(id,user_id,profile_id,schedule_revision,schedule_changed_at)
VALUES('00000000-0000-4000-8000-000000000071',auth.uid(),auth.uid(),99,now());
DO $$ BEGIN
 ASSERT (SELECT schedule_revision=0 AND schedule_changed_at IS NULL FROM public.trophy_help_requests WHERE id='00000000-0000-4000-8000-000000000071');
END $$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',true);
INSERT INTO public.trophy_help_responses(id,request_id,helper_user_id,helper_profile_id,status)
VALUES('00000000-0000-4000-8000-000000000072','00000000-0000-4000-8000-000000000071',auth.uid(),auth.uid(),'pending');
DO $$ BEGIN
 BEGIN PERFORM public.reschedule_coop_request('00000000-0000-4000-8000-000000000071',now()+interval '1 day',0,0); RAISE EXCEPTION 'helper changed timing'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
SELECT public.accept_coop_offer('00000000-0000-4000-8000-000000000072');
DO $$ DECLARE start_time timestamptz := now()+interval '2 days'; BEGIN
 PERFORM public.reschedule_coop_request('00000000-0000-4000-8000-000000000071',start_time,-240,0);
 PERFORM public.reschedule_coop_request('00000000-0000-4000-8000-000000000071',start_time,-240,0);
 ASSERT (SELECT schedule_revision=1 AND schedule_changed_at=now() AND scheduled_at=start_time AND status='assigned' FROM public.trophy_help_requests WHERE id='00000000-0000-4000-8000-000000000071');
 ASSERT (SELECT status='accepted' FROM public.trophy_help_responses WHERE id='00000000-0000-4000-8000-000000000072');
 BEGIN PERFORM public.reschedule_coop_request('00000000-0000-4000-8000-000000000071',start_time+interval '1 day',0,0); RAISE EXCEPTION 'stale write allowed'; EXCEPTION WHEN serialization_failure THEN NULL; END;
 BEGIN PERFORM public.reschedule_coop_request('00000000-0000-4000-8000-000000000071',now()-interval '1 day',0,1); RAISE EXCEPTION 'past time allowed'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.reschedule_coop_request('00000000-0000-4000-8000-000000000071',start_time,NULL,1); RAISE EXCEPTION 'missing offset allowed'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.reschedule_coop_request('00000000-0000-4000-8000-000000000071',start_time,900,1); RAISE EXCEPTION 'invalid offset allowed'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM public.reschedule_coop_request('00000000-0000-4000-8000-000000000071',NULL,NULL,1);
 ASSERT (SELECT schedule_revision=2 AND scheduled_at IS NULL AND session_utc_offset_minutes IS NULL FROM public.trophy_help_requests WHERE id='00000000-0000-4000-8000-000000000071');
 ASSERT NOT has_function_privilege('anon','public.reschedule_coop_request(uuid,timestamptz,integer,integer)','EXECUTE');
END $$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',true);
DO $$ BEGIN
 ASSERT (SELECT schedule_revision=2 AND schedule_changed_at IS NOT NULL FROM public.trophy_help_requests WHERE id='00000000-0000-4000-8000-000000000071');
END $$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
SELECT public.finish_coop_request('00000000-0000-4000-8000-000000000071','completed');
DO $$ BEGIN
 BEGIN PERFORM public.reschedule_coop_request('00000000-0000-4000-8000-000000000071',NULL,NULL,2); RAISE EXCEPTION 'completed request changed'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END $$;
ROLLBACK;
SELECT 'Rescheduling ownership, revision conflict, retries, validation and preserved team passed' AS result;
