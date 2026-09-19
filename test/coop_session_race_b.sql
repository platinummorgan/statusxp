DO $$ BEGIN IF current_database() <> 'statusxp_coop_sessions_test' THEN RAISE EXCEPTION 'Isolated test database required'; END IF; END $$;
BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
SELECT public.accept_coop_offer('00000000-0000-4000-8000-000000000033');
SELECT pg_sleep(2);
COMMIT;
