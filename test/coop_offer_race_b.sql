DO $$ BEGIN IF current_database() <> 'statusxp_coop_sessions_test' THEN RAISE EXCEPTION 'Isolated test database required'; END IF; END $$;
BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',true);
INSERT INTO public.trophy_help_responses VALUES ('00000000-0000-4000-8000-000000000043','00000000-0000-4000-8000-000000000014',auth.uid(),auth.uid(),'pending');
SELECT pg_sleep(1);
COMMIT;
