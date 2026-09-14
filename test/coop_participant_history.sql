-- Run only in a fresh isolated database; no production data is used.
DO $$ BEGIN IF current_database() <> 'statusxp_coop_test' THEN RAISE EXCEPTION 'Isolated test database required'; END IF; END $$;
CREATE SCHEMA auth;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
GRANT USAGE ON SCHEMA public, auth TO authenticated, anon;
CREATE TABLE public.trophy_help_requests(id uuid PRIMARY KEY, profile_id uuid, status text);
CREATE TABLE public.trophy_help_responses(id uuid PRIMARY KEY, request_id uuid REFERENCES public.trophy_help_requests, helper_profile_id uuid, helper_user_id uuid, status text);
ALTER TABLE public.trophy_help_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trophy_help_responses ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE ON public.trophy_help_requests, public.trophy_help_responses TO authenticated;
GRANT SELECT ON public.trophy_help_requests TO anon;
CREATE POLICY "Anyone can view open trophy help requests" ON public.trophy_help_requests FOR SELECT USING (status = 'open' OR auth.uid() = profile_id);
CREATE POLICY "Users can view responses for their requests or their own respon" ON public.trophy_help_responses FOR SELECT USING (auth.uid() = helper_profile_id OR auth.uid() IN (SELECT r.profile_id FROM public.trophy_help_requests r WHERE r.id = request_id));
\ir ../supabase/migrations/20260913120000_coop_participant_history.sql
\ir ../supabase/migrations/20260913120000_coop_participant_history.sql
INSERT INTO public.trophy_help_requests VALUES
 ('00000000-0000-4000-8000-000000000011', '00000000-0000-4000-8000-000000000001', 'assigned'),
 ('00000000-0000-4000-8000-000000000012', '00000000-0000-4000-8000-000000000001', 'completed'),
 ('00000000-0000-4000-8000-000000000013', '00000000-0000-4000-8000-000000000001', 'open');
INSERT INTO public.trophy_help_responses VALUES
 ('00000000-0000-4000-8000-000000000021', '00000000-0000-4000-8000-000000000011', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000002', 'accepted');
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',false);
DO $$ BEGIN
 ASSERT (SELECT count(*) FROM public.trophy_help_requests) = 2, 'helper must see assigned and open, not unrelated completed';
 ASSERT (SELECT count(*) FROM public.trophy_help_responses) = 1, 'response RLS must not recurse';
 INSERT INTO public.trophy_help_responses VALUES ('00000000-0000-4000-8000-000000000022','00000000-0000-4000-8000-000000000013',auth.uid(),auth.uid(),'pending');
 BEGIN
  INSERT INTO public.trophy_help_responses VALUES ('00000000-0000-4000-8000-000000000023','00000000-0000-4000-8000-000000000012',auth.uid(),auth.uid(),'pending');
  RAISE EXCEPTION 'closed request offer allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
  INSERT INTO public.trophy_help_responses VALUES ('00000000-0000-4000-8000-000000000024','00000000-0000-4000-8000-000000000013',auth.uid(),auth.uid(),'accepted');
  RAISE EXCEPTION 'forged acceptance allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
UPDATE public.trophy_help_requests SET status='completed' WHERE id='00000000-0000-4000-8000-000000000011';
SET ROLE authenticated;
DO $$ BEGIN ASSERT (SELECT count(*) FROM public.trophy_help_requests) = 2, 'completed partner history must remain visible'; END $$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000003',false);
DO $$ BEGIN ASSERT (SELECT count(*) FROM public.trophy_help_requests) = 1, 'unrelated user must only see open posts'; END $$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',false);
DO $$ BEGIN
 ASSERT (SELECT count(*) FROM public.trophy_help_requests) = 3, 'owner keeps history';
 ASSERT (SELECT count(*) FROM public.trophy_help_responses) = 2, 'owner keeps offers';
 BEGIN
  INSERT INTO public.trophy_help_responses VALUES ('00000000-0000-4000-8000-000000000025','00000000-0000-4000-8000-000000000013',auth.uid(),auth.uid(),'pending');
  RAISE EXCEPTION 'self offer allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SET ROLE anon;
SELECT set_config('request.jwt.claim.sub','',false);
DO $$ BEGIN ASSERT (SELECT count(*) FROM public.trophy_help_requests) = 1, 'anonymous users only see open'; END $$;
RESET ROLE;
SELECT 'Co-op participant history and offer boundaries passed' AS result;
