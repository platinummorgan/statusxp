-- Run after capturing flex_baselines and installing the candidate in a
-- transaction. The harness rolls back all function/visibility test changes.
DO $$
DECLARE b record; actual jsonb; target uuid := 'c6bfed69-3aa0-463e-99f8-4aceae89a7f4';
 viewer uuid := '84b60ad6-cb2c-484f-8953-bf814551fd7a'; started timestamptz; elapsed numeric;
 expected_count int; loaded int; sample record; facts record; tile record; max_count bigint; chosen_count bigint;
BEGIN
 FOR b IN SELECT * FROM flex_baselines LOOP
  SELECT jsonb_agg(to_jsonb(g) ORDER BY g.group_id) INTO actual FROM public.get_user_grouped_games(b.user_id) g;
  ASSERT actual=b.payload, 'Existing library fields must remain identical';
 END LOOP;
 SELECT count(*) INTO expected_count FROM public.user_progress up JOIN public.games g USING(platform_id,platform_game_id) WHERE up.user_id=target;
 PERFORM set_config('request.jwt.claim.sub',viewer::text,true);
 PERFORM set_config('request.jwt.claim.role','authenticated',true);
 EXECUTE 'SET LOCAL ROLE authenticated';
 started:=clock_timestamp();
 SELECT count(*) INTO loaded FROM public.get_public_user_grouped_games(target);
 elapsed:=extract(epoch FROM clock_timestamp()-started)*1000;
 ASSERT loaded=expected_count AND loaded>5000, 'Return the complete large library';
 ASSERT elapsed<8000, 'Large signed-in public history exceeds timeout: '||elapsed;
 EXECUTE 'RESET ROLE';
 INSERT INTO flex_checks VALUES('signed-in full public history',elapsed,loaded);
 -- Verify one returned game against source achievement/unlock rows, including
 -- score multiplier, trophy colors, totals, rarity and latest earned timestamp.
 SELECT * INTO sample FROM public.get_user_grouped_games(target) LIMIT 1;
 SELECT count(*) total,coalesce(sum(a.score_value),0) score INTO facts
 FROM public.achievements a WHERE a.platform_id=(sample.platforms[1]->>'platform_id')::bigint AND a.platform_game_id=sample.platforms[1]->>'platform_game_id';
 ASSERT (sample.platforms[1]->>'total_trophies')::bigint=facts.total, 'Potential achievements changed';
 ASSERT (sample.platforms[1]->>'total_score')::numeric=facts.score, 'Potential score changed';
 SELECT coalesce(sum(CASE WHEN a.include_in_score THEN a.base_status_xp*coalesce(a.rarity_multiplier,1.0) ELSE 0 END),0)::integer::numeric xp,
  count(*) FILTER(WHERE a.metadata->>'psn_trophy_type'='bronze') bronze,
  count(*) FILTER(WHERE a.metadata->>'psn_trophy_type'='silver') silver,
  count(*) FILTER(WHERE a.metadata->>'psn_trophy_type'='gold') gold,
  count(*) FILTER(WHERE a.metadata->>'psn_trophy_type'='platinum') platinum,
  min(a.rarity_global) rarest,max(ua.earned_at) latest
 INTO facts FROM public.user_achievement_unlocks ua JOIN public.achievements a USING(platform_id,platform_game_id,platform_achievement_id)
 WHERE ua.user_id=target AND ua.platform_id=(sample.platforms[1]->>'platform_id')::bigint AND ua.platform_game_id=sample.platforms[1]->>'platform_game_id';
 ASSERT sample.total_statusxp=facts.xp, 'Earned StatusXP changed';
 ASSERT (sample.platforms[1]->>'bronze_trophies')::bigint=facts.bronze AND (sample.platforms[1]->>'silver_trophies')::bigint=facts.silver
   AND (sample.platforms[1]->>'gold_trophies')::bigint=facts.gold AND (sample.platforms[1]->>'platinum_trophies')::bigint=facts.platinum, 'Trophy counts changed';
 ASSERT (sample.platforms[1]->>'rarest_achievement_rarity')::numeric IS NOT DISTINCT FROM facts.rarest, 'Rarity changed';
 ASSERT (sample.platforms[1]->>'last_trophy_earned_at')::timestamptz IS NOT DISTINCT FROM facts.latest, 'Earned timestamp changed';
 started:=clock_timestamp();
 SELECT * INTO tile FROM public.get_most_time_sunk_game_v2(target);
 elapsed:=extract(epoch FROM clock_timestamp()-started)*1000;
 ASSERT elapsed<8000, 'Most-time showcase exceeds timeout';
 SELECT max(c.n) INTO max_count FROM (SELECT count(*) n FROM public.user_achievements ua JOIN public.games g USING(platform_id,platform_game_id) WHERE ua.user_id=target AND ua.earned_at IS NOT NULL GROUP BY ua.platform_id,ua.platform_game_id)c;
 SELECT count(*) INTO chosen_count FROM public.user_achievements ua WHERE ua.user_id=target AND ua.platform_id=tile.platform_id AND ua.platform_game_id=tile.platform_game_id AND ua.earned_at IS NOT NULL;
 ASSERT chosen_count=max_count, 'Showcase must select a game with maximal earned count';
 ASSERT tile.earned_at=(SELECT max(ua.earned_at) FROM public.user_achievements ua JOIN public.achievements a USING(platform_id,platform_game_id,platform_achievement_id) WHERE ua.user_id=target AND ua.platform_id=tile.platform_id AND ua.platform_game_id=tile.platform_game_id), 'Showcase must select a latest owned trophy';
 INSERT INTO flex_checks VALUES('most-time showcase',elapsed,1);
 -- Visibility changes are only visible within this rollback transaction.
 UPDATE public.profiles_private SET show_on_leaderboard=false WHERE id=target;
 PERFORM set_config('request.jwt.claim.sub',viewer::text,true);
 PERFORM set_config('request.jwt.claim.role','authenticated',true);
 EXECUTE 'SET LOCAL ROLE authenticated';
 ASSERT NOT EXISTS(SELECT 1 FROM public.get_public_user_grouped_games(target)), 'Hidden profile must not be visible to another viewer';
 EXECUTE 'RESET ROLE';
 PERFORM set_config('request.jwt.claim.sub',target::text,true);
 EXECUTE 'SET LOCAL ROLE authenticated';
 ASSERT (SELECT count(*) FROM public.get_public_user_grouped_games(target))=expected_count, 'Owner keeps access to a hidden profile';
 EXECUTE 'RESET ROLE';
 PERFORM set_config('request.jwt.claim.sub','',true);
 PERFORM set_config('request.jwt.claim.role','anon',true);
 EXECUTE 'SET LOCAL ROLE anon';
 ASSERT NOT EXISTS(SELECT 1 FROM public.get_public_user_grouped_games(target)), 'Anonymous viewer cannot read a hidden profile';
 EXECUTE 'RESET ROLE';
 ASSERT NOT (SELECT prosecdef FROM pg_proc WHERE oid='public.get_user_grouped_games(uuid)'::regprocedure), 'Preserve invoker RLS';
END $$;
SELECT jsonb_agg(t) AS flex_checks FROM flex_checks t;
