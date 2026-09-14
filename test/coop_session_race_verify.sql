DO $$ BEGIN IF current_database() <> 'statusxp_coop_sessions_test' THEN RAISE EXCEPTION 'Isolated test database required'; END IF; END $$;
DO $$ BEGIN
 ASSERT (SELECT count(*) FROM public.trophy_help_responses WHERE request_id='00000000-0000-4000-8000-000000000012' AND status='accepted')=1;
 ASSERT (SELECT status FROM public.trophy_help_requests WHERE id='00000000-0000-4000-8000-000000000012')='assigned';
END $$;
-- Force a failure after the response write; the accepted response must roll back.
CREATE FUNCTION public.fixture_reject_assignment() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF NEW.id='00000000-0000-4000-8000-000000000013' AND NEW.status='assigned' THEN RAISE EXCEPTION 'fixture rejection'; END IF; RETURN NEW; END $$;
CREATE TRIGGER fixture_reject_assignment BEFORE UPDATE ON public.trophy_help_requests FOR EACH ROW EXECUTE FUNCTION public.fixture_reject_assignment();
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',false);
INSERT INTO public.trophy_help_responses VALUES('00000000-0000-4000-8000-000000000041','00000000-0000-4000-8000-000000000013',auth.uid(),auth.uid(),'pending');
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',false);
DO $$ BEGIN
 BEGIN PERFORM public.accept_coop_offer('00000000-0000-4000-8000-000000000041'); RAISE EXCEPTION 'failure not injected'; EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM='fixture rejection'; END;
 ASSERT (SELECT status FROM public.trophy_help_responses WHERE id='00000000-0000-4000-8000-000000000041')='pending';
 ASSERT (SELECT status FROM public.trophy_help_requests WHERE id='00000000-0000-4000-8000-000000000013')='open';
 PERFORM public.decline_coop_offer('00000000-0000-4000-8000-000000000041');
 PERFORM public.decline_coop_offer('00000000-0000-4000-8000-000000000041');
 PERFORM public.finish_coop_request('00000000-0000-4000-8000-000000000013','cancelled');
END $$;
RESET ROLE;
DROP TRIGGER fixture_reject_assignment ON public.trophy_help_requests;
DROP FUNCTION public.fixture_reject_assignment();
SELECT 'Concurrent capacity and acceptance rollback passed' AS result;
