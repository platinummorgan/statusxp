-- Run after capturing the current user's old response in library_baseline and
-- selecting representative accounts in library_users; append to the candidate
-- migration transaction before its COMMIT. All writes are temporary.
DO $$ DECLARE u uuid; r record; payload jsonb; expected jsonb; started timestamptz; elapsed numeric; game_count integer; BEGIN
 FOR u IN SELECT user_id FROM library_users LOOP
  PERFORM set_config('request.jwt.claim.sub',u::text,true);
  PERFORM set_config('request.jwt.claim.role','authenticated',true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  started:=clock_timestamp();
  SELECT COALESCE(jsonb_agg(to_jsonb(g) ORDER BY g.group_id),'[]') INTO payload FROM public.get_dashboard_games(u) g;
  elapsed:=extract(epoch FROM clock_timestamp()-started)*1000;
  SELECT count(*) INTO game_count FROM public.user_progress up JOIN public.games g USING(platform_id,platform_game_id) WHERE up.user_id=u;
  ASSERT jsonb_array_length(payload)=least(20,game_count),'Return only the dashboard page';
  ASSERT NOT EXISTS(SELECT 1 FROM public.get_dashboard_games('00000000-0000-4000-8000-000000009999')),'No other private account may be requested';
  EXECUTE 'RESET ROLE';
  SELECT * INTO r FROM library_baseline WHERE user_id=u;
  IF FOUND THEN
   SELECT COALESCE(jsonb_agg(g ORDER BY g->>'group_id'),'[]') INTO expected FROM jsonb_array_elements(r.payload) g
    WHERE EXISTS(SELECT 1 FROM jsonb_array_elements(payload) p WHERE p->>'group_id'=g->>'group_id');
   ASSERT payload=expected,'Detailed fields must match the existing library';
  END IF;
  ASSERT elapsed<8000,'Dashboard request exceeds the signed-in timeout: '||elapsed||'ms';
  INSERT INTO library_timings VALUES(u,r.elapsed_ms,elapsed,jsonb_array_length(payload));
 END LOOP;
 ASSERT NOT (SELECT prosecdef FROM pg_proc WHERE oid='public.get_dashboard_games(uuid)'::regprocedure),'Keep invoker security';
 ASSERT NOT has_function_privilege('anon','public.get_dashboard_games(uuid)','EXECUTE');
END $$;
SELECT jsonb_agg(t) AS library_timings FROM library_timings t;
