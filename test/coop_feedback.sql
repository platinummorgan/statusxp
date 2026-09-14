DO $$ BEGIN IF current_database()<>'statusxp_coop_sessions_test' THEN RAISE EXCEPTION 'Isolated co-op database required'; END IF; END $$;
CREATE TABLE IF NOT EXISTS public.profiles(id uuid PRIMARY KEY);
INSERT INTO public.profiles(id) SELECT ('00000000-0000-4000-8000-00000000000'||i)::uuid FROM generate_series(1,4) i ON CONFLICT DO NOTHING;
\ir ../supabase/migrations/20260913180000_coop_feedback_outcomes.sql
\ir ../supabase/migrations/20260913180000_coop_feedback_outcomes.sql
DO $$ BEGIN
 ASSERT (SELECT first_accepted_at IS NULL AND finished_at IS NULL FROM public.coop_request_outcomes WHERE request_id='00000000-0000-4000-8000-000000000011'), 'historical event times must not be fabricated';
END $$;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',false);
DO $$ BEGIN
 PERFORM public.save_coop_feedback('00000000-0000-4000-8000-000000000011','goal_completed',true);
 PERFORM public.save_coop_feedback('00000000-0000-4000-8000-000000000011','made_progress',NULL);
 ASSERT (SELECT count(*) FROM public.coop_session_feedback)=1;
 ASSERT (SELECT outcome FROM public.coop_session_feedback)='made_progress';
 BEGIN INSERT INTO public.coop_session_feedback(request_id,user_id,outcome) VALUES('00000000-0000-4000-8000-000000000011',auth.uid(),'goal_completed'); RAISE EXCEPTION 'direct insert allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.save_coop_feedback('00000000-0000-4000-8000-000000000014','goal_completed',true); RAISE EXCEPTION 'open request feedback allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.save_coop_feedback('00000000-0000-4000-8000-000000000011','invented',true); RAISE EXCEPTION 'invalid outcome allowed'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000004',false);
DO $$ BEGIN
 ASSERT (SELECT count(*) FROM public.coop_session_feedback)=0;
 BEGIN PERFORM public.save_coop_feedback('00000000-0000-4000-8000-000000000011','goal_completed',true); RAISE EXCEPTION 'declined helper feedback allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',false);
DO $$ BEGIN
 ASSERT (SELECT count(*) FROM public.coop_session_feedback)=0, 'host must not read helper private feedback';
 PERFORM public.save_coop_feedback('00000000-0000-4000-8000-000000000011','goal_completed',true);
 ASSERT (SELECT count(*) FROM public.coop_session_feedback)=1;
 ASSERT NOT has_table_privilege('authenticated','public.coop_request_outcomes','SELECT');
 ASSERT NOT has_function_privilege('anon','public.save_coop_feedback(uuid,text,boolean)','EXECUTE');
END $$;
RESET ROLE;
SELECT 'Feedback eligibility, privacy, replay and historical timestamps passed' AS result;
