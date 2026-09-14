DO $$ BEGIN IF current_database() <> 'statusxp_coop_sessions_test' THEN RAISE EXCEPTION 'Run the session-planning fixture in its isolated database first'; END IF; END $$;
\ir ../supabase/migrations/20260913160000_coop_request_confirmation.sql
\ir ../supabase/migrations/20260913160000_coop_request_confirmation.sql
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',false);
DO $$ BEGIN
 BEGIN PERFORM public.reconfirm_coop_request('00000000-0000-4000-8000-000000000014'); RAISE EXCEPTION 'non-owner confirmed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',false);
DO $$ BEGIN
 PERFORM public.reconfirm_coop_request('00000000-0000-4000-8000-000000000014');
 ASSERT (SELECT last_confirmed_at FROM public.trophy_help_requests WHERE id='00000000-0000-4000-8000-000000000014')=now();
 BEGIN PERFORM public.reconfirm_coop_request('00000000-0000-4000-8000-000000000011'); RAISE EXCEPTION 'completed request confirmed'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 ASSERT NOT has_function_privilege('anon','public.reconfirm_coop_request(uuid,boolean)','EXECUTE');
 BEGIN UPDATE public.trophy_help_requests SET last_confirmed_at=now(); RAISE EXCEPTION 'direct timestamp update allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 INSERT INTO public.trophy_help_requests(id,user_id,profile_id,last_confirmed_at)
 VALUES('00000000-0000-4000-8000-000000000019',auth.uid(),auth.uid(),now()+interval '1 year');
 ASSERT (SELECT last_confirmed_at FROM public.trophy_help_requests WHERE id='00000000-0000-4000-8000-000000000019') IS NULL;
END $$;
RESET ROLE;
UPDATE public.trophy_help_requests SET scheduled_at=now()-interval '1 day', session_utc_offset_minutes=-240 WHERE id='00000000-0000-4000-8000-000000000014';
SET ROLE authenticated;
DO $$ DECLARE future_start timestamptz; BEGIN
 BEGIN PERFORM public.reconfirm_coop_request('00000000-0000-4000-8000-000000000014'); RAISE EXCEPTION 'stale schedule confirmed'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM public.reconfirm_coop_request('00000000-0000-4000-8000-000000000014',true);
 ASSERT (SELECT scheduled_at IS NULL AND session_utc_offset_minutes IS NULL FROM public.trophy_help_requests WHERE id='00000000-0000-4000-8000-000000000014');
 SELECT scheduled_at INTO future_start FROM public.trophy_help_requests WHERE id='00000000-0000-4000-8000-000000000015';
 PERFORM public.reconfirm_coop_request('00000000-0000-4000-8000-000000000015',true);
 ASSERT (SELECT scheduled_at FROM public.trophy_help_requests WHERE id='00000000-0000-4000-8000-000000000015')=future_start;
END $$;
RESET ROLE;
SELECT 'Confirmation ownership, server timestamp, stale schedule and field preservation passed' AS result;
