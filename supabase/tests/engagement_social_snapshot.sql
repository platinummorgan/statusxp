-- Read-only regression after adding idx_ua_user_earned_cover.
BEGIN;
SET LOCAL statement_timeout='8s';
CREATE TEMP TABLE engagement_check(query_ms numeric,returned_players int);
DO $$
DECLARE actor uuid; other_actor uuid; rows jsonb; first_row jsonb; expected_week bigint; expected_month bigint;
  started timestamptz; elapsed numeric; eligible int;
BEGIN
  SELECT lc.user_id INTO actor FROM public.leaderboard_cache lc ORDER BY lc.total_statusxp DESC LIMIT 1;
  ASSERT actor IS NOT NULL, 'Select an existing test account';
  SELECT p.id INTO other_actor FROM public.profiles p WHERE p.id<>actor LIMIT 1;
  SELECT count(*) INTO eligible FROM public.leaderboard_cache lc JOIN public.profiles p ON p.id=lc.user_id WHERE p.show_on_leaderboard AND lc.user_id<>actor;
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  PERFORM set_config('request.jwt.claim.role','authenticated',true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  started:=clock_timestamp();
  SELECT COALESCE(jsonb_agg(to_jsonb(r) ORDER BY r.total_statusxp DESC,r.user_id),'[]') INTO rows FROM public.get_social_graph_snapshot(actor,30) r;
  elapsed:=extract(epoch FROM clock_timestamp()-started)*1000;
  ASSERT jsonb_array_length(rows)=least(eligible,30), 'Preserve the full social list';
  ASSERT elapsed<8000, 'Signed-in social query exceeds the application timeout';
  ASSERT NOT EXISTS(SELECT 1 FROM public.get_social_graph_snapshot(actor,30) r WHERE r.user_id=actor), 'Exclude the viewer';
  ASSERT NOT EXISTS(SELECT 1 FROM public.get_social_graph_snapshot(other_actor,30)), 'No cross-account graph access';
  SELECT to_jsonb(r) INTO first_row FROM public.get_social_graph_snapshot(actor,1) r;
  ASSERT first_row=rows->0, 'Preserve ranking and limit behavior';
  EXECUTE 'RESET ROLE';
  IF first_row IS NOT NULL THEN
    SELECT
      COALESCE(SUM(a.base_status_xp) FILTER(WHERE ua.earned_at>=public.get_leaderboard_period_start('weekly',now()) AND ua.earned_at<public.get_leaderboard_period_start('weekly',now())+interval '7 days'),0)::bigint,
      COALESCE(SUM(a.base_status_xp) FILTER(WHERE ua.earned_at>=public.get_leaderboard_period_start('monthly',now()) AND ua.earned_at<public.get_leaderboard_period_start('monthly',now())+interval '1 month'),0)::bigint
    INTO expected_week,expected_month
    FROM public.user_achievements ua JOIN public.achievements a USING(platform_id,platform_game_id,platform_achievement_id)
    WHERE ua.user_id=(first_row->>'user_id')::uuid AND COALESCE(a.include_in_score,true)
      AND ua.earned_at>=LEAST(public.get_leaderboard_period_start('weekly',now()),public.get_leaderboard_period_start('monthly',now()))
      AND ua.earned_at<GREATEST(public.get_leaderboard_period_start('weekly',now())+interval '7 days',public.get_leaderboard_period_start('monthly',now())+interval '1 month');
    ASSERT (first_row->>'weekly_gain')::bigint=expected_week, 'Weekly gains must retain their value';
    ASSERT (first_row->>'monthly_gain')::bigint=expected_month, 'Monthly gains must retain their value';
  END IF;
  PERFORM set_config('request.jwt.claim.sub','',true);
  PERFORM set_config('request.jwt.claim.role','anon',true);
  EXECUTE 'SET LOCAL ROLE anon';
  ASSERT NOT EXISTS(SELECT 1 FROM public.get_social_graph_snapshot(actor,30)), 'Anonymous requests must return no graph';
  EXECUTE 'RESET ROLE';
  ASSERT (SELECT indisvalid FROM pg_index WHERE indexrelid='public.idx_ua_user_earned_cover'::regclass), 'The production index must be valid';
  INSERT INTO engagement_check VALUES(elapsed,jsonb_array_length(rows));
END $$;
SELECT * FROM engagement_check;
ROLLBACK;
