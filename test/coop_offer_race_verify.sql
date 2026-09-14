DO $$ BEGIN IF current_database() <> 'statusxp_coop_sessions_test' THEN RAISE EXCEPTION 'Isolated test database required'; END IF;
ASSERT (SELECT count(*) FROM public.trophy_help_responses WHERE request_id='00000000-0000-4000-8000-000000000014' AND helper_profile_id='00000000-0000-4000-8000-000000000002')=1, 'Concurrent duplicate offers must produce one row'; END $$;
