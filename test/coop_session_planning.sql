-- Fresh isolated PostgreSQL fixture only.
DO $$ BEGIN IF current_database() <> 'statusxp_coop_sessions_test' THEN RAISE EXCEPTION 'Isolated test database required'; END IF; END $$;
CREATE SCHEMA auth;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
GRANT USAGE ON SCHEMA public, auth TO authenticated, anon;
CREATE TABLE public.trophy_help_requests(id uuid PRIMARY KEY, user_id uuid NOT NULL, profile_id uuid NOT NULL, status text NOT NULL DEFAULT 'open');
CREATE TABLE public.trophy_help_responses(id uuid PRIMARY KEY, request_id uuid REFERENCES public.trophy_help_requests, helper_profile_id uuid NOT NULL, helper_user_id uuid NOT NULL, status text NOT NULL DEFAULT 'pending');
ALTER TABLE public.trophy_help_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trophy_help_responses ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE ON public.trophy_help_requests, public.trophy_help_responses TO authenticated;
CREATE POLICY "Anyone can view open trophy help requests" ON public.trophy_help_requests FOR SELECT USING (status='open' OR auth.uid()=profile_id);
CREATE POLICY responses_read ON public.trophy_help_responses FOR SELECT USING (auth.uid()=helper_profile_id OR auth.uid() IN (SELECT profile_id FROM public.trophy_help_requests WHERE id=request_id));
CREATE POLICY owner_updates ON public.trophy_help_requests FOR UPDATE USING (profile_id=auth.uid());
CREATE POLICY owner_response_updates ON public.trophy_help_responses FOR UPDATE USING (auth.uid() IN (SELECT profile_id FROM public.trophy_help_requests WHERE id=request_id));
\ir ../supabase/migrations/20260913120000_coop_participant_history.sql
INSERT INTO public.trophy_help_requests SELECT ('00000000-0000-4000-8000-00000000001'||i)::uuid,'00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000001','open' FROM generate_series(1,4) i;
INSERT INTO public.trophy_help_responses SELECT ('00000000-0000-4000-8000-00000000002'||i)::uuid,'00000000-0000-4000-8000-000000000011',('00000000-0000-4000-8000-00000000000'||i)::uuid,('00000000-0000-4000-8000-00000000000'||i)::uuid,'pending' FROM generate_series(2,4) i;
INSERT INTO public.trophy_help_responses SELECT ('00000000-0000-4000-8000-00000000003'||i)::uuid,'00000000-0000-4000-8000-000000000012',('00000000-0000-4000-8000-00000000000'||i)::uuid,('00000000-0000-4000-8000-00000000000'||i)::uuid,'pending' FROM generate_series(2,3) i;
-- Historical duplicate preserved instead of deleting user history during migration.
INSERT INTO public.trophy_help_responses VALUES ('00000000-0000-4000-8000-000000000029','00000000-0000-4000-8000-000000000011','00000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000002','pending');
\ir ../supabase/migrations/20260913140000_coop_session_planning.sql
\ir ../supabase/migrations/20260913140000_coop_session_planning.sql
UPDATE public.trophy_help_requests SET helpers_needed=2 WHERE id='00000000-0000-4000-8000-000000000011';
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',false);
DO $$ BEGIN
 BEGIN PERFORM public.accept_coop_offer('00000000-0000-4000-8000-000000000022'); RAISE EXCEPTION 'helper accepted self'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
  INSERT INTO public.trophy_help_responses VALUES ('00000000-0000-4000-8000-000000000028','00000000-0000-4000-8000-000000000011',auth.uid(),auth.uid(),'pending');
  RAISE EXCEPTION 'duplicate inserted';
 EXCEPTION WHEN unique_violation THEN NULL; END;
 BEGIN UPDATE public.trophy_help_responses SET status='accepted'; RAISE EXCEPTION 'direct response update allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',false);
DO $$ BEGIN
 ASSERT NOT has_table_privilege('authenticated','public.trophy_help_requests','UPDATE');
 ASSERT NOT has_function_privilege('anon','public.accept_coop_offer(uuid)','EXECUTE');
 PERFORM public.accept_coop_offer('00000000-0000-4000-8000-000000000022');
 PERFORM public.accept_coop_offer('00000000-0000-4000-8000-000000000022');
 ASSERT (SELECT status FROM public.trophy_help_requests WHERE id='00000000-0000-4000-8000-000000000011')='open';
 BEGIN PERFORM public.accept_coop_offer('00000000-0000-4000-8000-000000000029'); RAISE EXCEPTION 'same helper counted twice'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM public.accept_coop_offer('00000000-0000-4000-8000-000000000023');
 ASSERT (SELECT status FROM public.trophy_help_requests WHERE id='00000000-0000-4000-8000-000000000011')='assigned';
 ASSERT (SELECT count(*) FROM public.trophy_help_responses WHERE request_id='00000000-0000-4000-8000-000000000011' AND status='accepted')=2;
 ASSERT (SELECT status FROM public.trophy_help_responses WHERE id='00000000-0000-4000-8000-000000000024')='declined';
 BEGIN PERFORM public.accept_coop_offer('00000000-0000-4000-8000-000000000024'); RAISE EXCEPTION 'capacity exceeded'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM public.finish_coop_request('00000000-0000-4000-8000-000000000011','completed');
 PERFORM public.finish_coop_request('00000000-0000-4000-8000-000000000011','completed');
 ASSERT (SELECT count(*) FROM public.trophy_help_responses WHERE request_id='00000000-0000-4000-8000-000000000011' AND status='completed')=2;
 BEGIN PERFORM public.finish_coop_request('00000000-0000-4000-8000-000000000011','cancelled'); RAISE EXCEPTION 'terminal state changed'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.finish_coop_request('00000000-0000-4000-8000-000000000013','assigned'); RAISE EXCEPTION 'assigned forged'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 INSERT INTO public.trophy_help_requests(id,user_id,profile_id,scheduled_at,session_utc_offset_minutes,helpers_needed)
 VALUES('00000000-0000-4000-8000-000000000015',auth.uid(),auth.uid(),now()+interval '1 day',-240,3);
 BEGIN
  INSERT INTO public.trophy_help_requests(id,user_id,profile_id,scheduled_at,session_utc_offset_minutes)
  VALUES('00000000-0000-4000-8000-000000000016',auth.uid(),auth.uid(),now()-interval '1 hour',0);
  RAISE EXCEPTION 'past time allowed';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN
  INSERT INTO public.trophy_help_requests(id,user_id,profile_id,helpers_needed)
  VALUES('00000000-0000-4000-8000-000000000017',auth.uid(),auth.uid(),0);
  RAISE EXCEPTION 'invalid group allowed';
 EXCEPTION WHEN check_violation THEN NULL; END;
 BEGIN
  INSERT INTO public.trophy_help_requests(id,user_id,profile_id,scheduled_at)
  VALUES('00000000-0000-4000-8000-000000000018',auth.uid(),auth.uid(),now()+interval '1 day');
  RAISE EXCEPTION 'missing time zone allowed';
 EXCEPTION WHEN check_violation THEN NULL; END;
END $$;
RESET ROLE;
SELECT 'Session fields, ownership, duplicate prevention, capacity, retries and completion passed' AS result;
