BEGIN;
SET LOCAL statement_timeout='120s';
INSERT INTO auth.users(id,email,raw_user_meta_data)
VALUES('00000000-0000-4000-8000-000000011517','steam-completion-11517@statusxp.invalid','{"display_name":"Steam completion fixture"}');
UPDATE public.profiles_private SET show_on_leaderboard=true,steam_id='76561190000011517',steam_sync_status='syncing'
 WHERE id='00000000-0000-4000-8000-000000011517';
INSERT INTO public.steam_sync_logs(id,user_id,sync_type,status,started_at)
VALUES(-11517,'00000000-0000-4000-8000-000000011517','full','syncing',now());
INSERT INTO public.games(platform_id,platform_game_id,name) VALUES(4,'steam-completion-fixture-11517','Steam completion fixture');
INSERT INTO public.achievements(platform_id,platform_game_id,platform_achievement_id,name,rarity_global,include_in_score,rarity_multiplier)
VALUES(4,'steam-completion-fixture-11517','BASE_A','Base A',1,true,1),
(4,'steam-completion-fixture-11517','STEAM_EXCLUSIVE','Day one Steam exclusive',50,true,1),
(4,'steam-completion-fixture-11517','DLC','Later DLC',0,true,1);
INSERT INTO public.user_progress(user_id,platform_id,platform_game_id,current_score,achievements_earned,total_achievements)
VALUES('00000000-0000-4000-8000-000000011517',4,'steam-completion-fixture-11517',2,2,3);
INSERT INTO public.user_achievements(user_id,platform_id,platform_game_id,platform_achievement_id,earned_at)
VALUES('00000000-0000-4000-8000-000000011517',4,'steam-completion-fixture-11517','BASE_A',now()),
('00000000-0000-4000-8000-000000011517',4,'steam-completion-fixture-11517','STEAM_EXCLUSIVE',now());
DO $$
DECLARE u uuid:='00000000-0000-4000-8000-000000011517'; app text:='steam-completion-fixture-11517';
 schema_names text[]:=ARRAY['BASE_A','STEAM_EXCLUSIVE','DLC']; states jsonb; incomplete jsonb;
 evidence jsonb:='{"scope":"day_one_base_game","sources":["https://example.invalid/original-release-fixture"]}';
BEGIN
 PERFORM set_config('request.jwt.claims','{"role":"service_role"}',true);
 states:=jsonb_build_array(
  jsonb_build_object('apiname','BASE_A','achieved',1,'unlocktime',extract(epoch FROM now()-interval '30 seconds')::bigint),
  jsonb_build_object('apiname','STEAM_EXCLUSIVE','achieved',1,'unlocktime',extract(epoch FROM now()-interval '10 seconds')::bigint),
  jsonb_build_object('apiname','DLC','achieved',0,'unlocktime',0));
 ASSERT (SELECT completion_count IS NULL FROM public.get_steam_completion_stats(u)), 'Unsynced completion count is unknown';
 PERFORM public.record_steam_completion(u,'76561190000011517',-11517,app,schema_names,states);
 PERFORM public.mark_steam_completions_synced(u,'76561190000011517',-11517);
 ASSERT NOT EXISTS(SELECT 1 FROM public.steam_completion_awards WHERE user_id=u), 'Default/unreviewed groups cannot grant awards';
 ASSERT (SELECT completion_count=0 AND pending_review_count=1 FROM public.get_steam_completion_stats(u)), 'Unreviewed coverage must be visible';
 PERFORM public.review_steam_completion_set(app,ARRAY['BASE_A','STEAM_EXCLUSIVE'],ARRAY['DLC'],evidence);
 PERFORM public.record_steam_completion(u,'76561190000011517',-11517,app,schema_names,states);
 PERFORM public.record_steam_completion(u,'76561190000011517',-11517,app,schema_names,states);
 ASSERT (SELECT count(*)=1 AND min(base_status_xp)=56.29 AND min(estimated_rarity)=1
  FROM public.steam_completion_awards WHERE user_id=u), 'One award uses required minimum, excluding rarer locked DLC';
 ASSERT (SELECT completion_count=1 AND pending_review_count=0 FROM public.get_steam_completion_stats(u)), 'Dashboard counts reviewed base completions';
 ASSERT (SELECT completion_count=1 FROM public.get_steam_completion_leaderboard(1000,0) WHERE user_id=u), 'Leaderboard uses completions';
 ASSERT (SELECT period_gain=1 FROM public.get_steam_completion_period_leaderboard('weekly',1000,0) WHERE user_id=u), 'Seasonal gains count real dated completions';
 ASSERT (SELECT sum(period_gain)=1 FROM public.get_user_seasonal_game_breakdown(u,'steam','weekly',200,0)), 'Steam seasonal breakdown uses completions';
 ASSERT (SELECT statusxp_effective=70 AND achievements_earned=2 FROM public.calculate_statusxp_with_stacks(u)), 'Combine bonus and ordinary points before game rounding';
 ASSERT (SELECT total_statusxp=70 FROM public.get_dashboard_games(u)), 'Dashboard game total reconciles';
 ASSERT (SELECT total_statusxp=70 FROM public.get_user_grouped_games(u)), 'Library game total reconciles';
 incomplete:=jsonb_set(states,'{1,achieved}','0');
 PERFORM public.record_steam_completion(u,'76561190000011517',-11517,app,schema_names,incomplete);
 ASSERT NOT EXISTS(SELECT 1 FROM public.steam_completion_awards WHERE user_id=u), 'Day-one Steam exclusives are required even when stale stored unlocks remain';
 PERFORM public.record_steam_completion(u,'76561190000011517',-11517,app,schema_names,jsonb_set(states,'{1,unlocktime}','0'));
 ASSERT (SELECT earned_at IS NULL FROM public.steam_completion_awards WHERE user_id=u), 'Unknown dates remain unknown';
 ASSERT (SELECT period_gain=0 AND completion_count=1 FROM public.get_steam_completion_period_leaderboard('weekly',1000,0) WHERE user_id=u), 'Undated completions count all-time only';
 UPDATE public.achievements SET rarity_global=0 WHERE platform_id=4 AND platform_game_id=app AND platform_achievement_id='BASE_A';
 PERFORM public.record_steam_completion(u,'76561190000011517',-11517,app,schema_names,states);
 ASSERT (SELECT estimated_rarity=0 AND base_status_xp=58 FROM public.steam_completion_awards WHERE user_id=u), 'Zero rarity is valid';
 UPDATE public.achievements SET rarity_global=1 WHERE platform_id=4 AND platform_game_id=app AND platform_achievement_id='BASE_A';
 PERFORM public.record_steam_completion(u,'76561190000011517',-11517,app,schema_names,states);
 PERFORM public.refresh_statusxp_leaderboard_for_user(u);
 ASSERT (SELECT total_statusxp=70 AND potential_statusxp=82 AND total_game_entries=1 FROM public.leaderboard_cache WHERE user_id=u), 'Per-user totals and potential reconcile';
 ASSERT NOT has_function_privilege('authenticated','public.review_steam_completion_set(text,text[],text[],jsonb)','EXECUTE'), 'Reviews are server-owned';
 ASSERT NOT has_table_privilege('anon','public.steam_completion_progress','SELECT'), 'Provider identity is private';
 ASSERT NOT has_table_privilege('authenticated','public.steam_completion_catalog','TRUNCATE'), 'Catalog cannot be cleared by clients';
END; $$;
SELECT public.refresh_statusxp_leaderboard();
DO $$ BEGIN
 ASSERT (SELECT total_statusxp=70 AND potential_statusxp=82 AND total_game_entries=1
 FROM public.leaderboard_cache WHERE user_id='00000000-0000-4000-8000-000000011517'), 'Full refresh matches per-user totals';
END; $$;
SELECT 'Steam completion scoring assertions passed' result;
ROLLBACK;
