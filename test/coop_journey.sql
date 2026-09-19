DO $$ BEGIN IF current_database()<>'statusxp_coop_sessions_test' THEN RAISE EXCEPTION 'Isolated co-op database required'; END IF; END $$;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',false);
INSERT INTO public.trophy_help_requests(id,user_id,profile_id,helpers_needed,scheduled_at,session_utc_offset_minutes)
 VALUES('00000000-0000-4000-8000-000000000061',auth.uid(),auth.uid(),1,now()+interval '1 day',-240);
SELECT public.reconfirm_coop_request('00000000-0000-4000-8000-000000000061');
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',false);
INSERT INTO public.trophy_help_responses(id,request_id,helper_profile_id,helper_user_id,status)
 VALUES('00000000-0000-4000-8000-000000000062','00000000-0000-4000-8000-000000000061',auth.uid(),auth.uid(),'pending');
DO $$ BEGIN
 BEGIN PERFORM public.save_coop_feedback('00000000-0000-4000-8000-000000000061','goal_completed',true); RAISE EXCEPTION 'premature feedback allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',false);
SELECT public.accept_coop_offer('00000000-0000-4000-8000-000000000062');
SELECT public.accept_coop_offer('00000000-0000-4000-8000-000000000062');
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',false);
DO $$ BEGIN
 ASSERT (SELECT status FROM public.trophy_help_requests WHERE id='00000000-0000-4000-8000-000000000061')='assigned';
 ASSERT (SELECT status FROM public.trophy_help_responses WHERE id='00000000-0000-4000-8000-000000000062')='accepted';
END $$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',false);
SELECT public.finish_coop_request('00000000-0000-4000-8000-000000000061','completed');
SELECT public.finish_coop_request('00000000-0000-4000-8000-000000000061','completed');
SELECT public.save_coop_feedback('00000000-0000-4000-8000-000000000061','goal_completed',true);
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',false);
SELECT public.save_coop_feedback('00000000-0000-4000-8000-000000000061','made_progress',NULL);
SELECT public.save_coop_feedback('00000000-0000-4000-8000-000000000061','made_progress',NULL);
DO $$ BEGIN
 ASSERT (SELECT count(*) FROM public.coop_session_feedback WHERE request_id='00000000-0000-4000-8000-000000000061')=1;
 ASSERT (SELECT outcome FROM public.coop_session_feedback WHERE request_id='00000000-0000-4000-8000-000000000061')='made_progress';
END $$;
RESET ROLE;
DO $$ BEGIN
 ASSERT (SELECT count(*) FROM public.coop_session_feedback WHERE request_id='00000000-0000-4000-8000-000000000061')=2;
 ASSERT (SELECT first_accepted_at IS NOT NULL AND finished_at >= first_accepted_at AND request_status='completed' FROM public.coop_request_outcomes WHERE request_id='00000000-0000-4000-8000-000000000061');
END $$;
SELECT 'Create, reconfirm, offer, accept, participant access, complete, private feedback and outcomes passed' AS result;
