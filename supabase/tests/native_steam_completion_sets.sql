BEGIN;
SET LOCAL statement_timeout='120s';
INSERT INTO auth.users(id,email,raw_user_meta_data)
 VALUES('00000000-0000-4000-8000-000000011618','native-steam-11618@statusxp.invalid','{"display_name":"Native Steam fixture"}');
UPDATE public.profiles_private SET show_on_leaderboard=true,steam_id='76561190000011618',steam_sync_status='syncing'
 WHERE id='00000000-0000-4000-8000-000000011618';
INSERT INTO public.steam_sync_logs(id,user_id,sync_type,status,started_at)
 VALUES(-11618,'00000000-0000-4000-8000-000000011618','full','syncing',now());
INSERT INTO public.games(platform_id,platform_game_id,name) VALUES(4,'90000011618','Native Steam fixture');
INSERT INTO public.achievements(platform_id,platform_game_id,platform_achievement_id,name,rarity_global,include_in_score,rarity_multiplier)
 VALUES(4,'90000011618','BASE','Base',1,true,1),(4,'90000011618','EXCLUSIVE','Steam exclusive',50,true,1),
 (4,'90000011618','DLC','DLC',0,true,1);
INSERT INTO public.user_progress(user_id,platform_id,platform_game_id,current_score,achievements_earned,total_achievements)
 VALUES('00000000-0000-4000-8000-000000011618',4,'90000011618',2,2,3);
INSERT INTO public.user_achievements(user_id,platform_id,platform_game_id,platform_achievement_id,earned_at)
 VALUES('00000000-0000-4000-8000-000000011618',4,'90000011618','BASE',now()),
 ('00000000-0000-4000-8000-000000011618',4,'90000011618','EXCLUSIVE',now());
DO $$
DECLARE u uuid:='00000000-0000-4000-8000-000000011618'; app text:='90000011618';
 ids text[]:=ARRAY['BASE','DLC','EXCLUSIVE']; states jsonb; rev text;
 base_evidence jsonb:='{"scope":"official_base_game","review_method":"automatic_native_steam_sets","policy_version":1}';
 all_evidence jsonb:='{"scope":"all_achievements","review_method":"automatic_native_steam_sets","policy_version":1}';
BEGIN
 PERFORM set_config('request.jwt.claims','{"role":"service_role"}',true);
 states:='[{"apiname":"BASE","achieved":1,"unlocktime":0},{"apiname":"DLC","achieved":0,"unlocktime":0},{"apiname":"EXCLUSIVE","achieved":1,"unlocktime":0}]';
 ASSERT public.apply_steam_completion_policy(app,ids,ARRAY['BASE','EXCLUSIVE'],'official_base_game',base_evidence,NULL,false);
 PERFORM public.record_steam_completion(u,'76561190000011618',-11618,app,ids,states);
 PERFORM public.mark_steam_completions_synced(u,'76561190000011618',-11618);
 PERFORM public.record_steam_completion(u,'76561190000011618',-11618,app,ids,states);
 ASSERT (SELECT count(*)=1 AND min(base_status_xp)=11.66 AND min(estimated_rarity)=1
  FROM public.steam_completion_awards WHERE user_id=u), 'Native base award once, 1x, excluding rarer DLC';
 ASSERT (SELECT earned_at IS NULL FROM public.steam_completion_awards WHERE user_id=u), 'Do not invent native dates';
 ASSERT (SELECT completion_count=1 AND pending_review_count=0 FROM public.get_steam_completion_stats(u));
 ASSERT (SELECT completion_count=1 FROM public.get_steam_completion_leaderboard(1000,0) WHERE user_id=u);
 ASSERT (SELECT statusxp_effective=25 FROM public.calculate_statusxp_with_stacks(u)), 'Canonical combines ordinary and completion points';
 ASSERT (SELECT total_statusxp=25 FROM public.get_dashboard_games(u));
 PERFORM public.refresh_statusxp_leaderboard_for_user(u);
 ASSERT (SELECT total_statusxp=25 AND potential_statusxp=37 FROM public.leaderboard_cache WHERE user_id=u);
 -- Definition changes invalidate the previous native completion until rechecked.
 ASSERT public.apply_steam_completion_policy(app,ids,ids,'all_achievements',all_evidence,ids,false);
 ASSERT NOT EXISTS(SELECT 1 FROM public.steam_completion_awards WHERE user_id=u);
 ASSERT (SELECT pending_review_count=1 FROM public.get_steam_completion_stats(u));
 PERFORM public.record_steam_completion(u,'76561190000011618',-11618,app,ids,states);
 ASSERT NOT EXISTS(SELECT 1 FROM public.steam_completion_awards WHERE user_id=u), 'Full fallback includes locked DLC';
 ASSERT (SELECT completion_count=0 AND pending_review_count=0 FROM public.get_steam_completion_stats(u));
 states:=jsonb_set(states,'{1,achieved}','1');
 PERFORM public.record_steam_completion(u,'76561190000011618',-11618,app,ids,states);
 ASSERT (SELECT count(*)=1 AND min(estimated_rarity)=0 AND min(base_status_xp)=12
  FROM public.steam_completion_awards WHERE user_id=u), 'Fallback rarity uses same IDs, including valid zero';
 -- Reverting to base never permits omission of a Steam-exclusive required ID.
 ASSERT public.apply_steam_completion_policy(app,ids,ARRAY['BASE','EXCLUSIVE'],'official_base_game',base_evidence,ids,false);
 PERFORM public.record_steam_completion(u,'76561190000011618',-11618,app,ids,jsonb_set(states,'{2,achieved}','0'));
 ASSERT NOT EXISTS(SELECT 1 FROM public.steam_completion_awards WHERE user_id=u);
 ASSERT NOT public.apply_steam_completion_policy(app,ids,ids,'all_achievements',all_evidence,ARRAY['STALE'],false), 'CAS rejects stale provider jobs';
 UPDATE public.achievements SET rarity_global=NULL WHERE platform_id=4 AND platform_game_id=app AND platform_achievement_id='BASE';
 PERFORM public.record_steam_completion(u,'76561190000011618',-11618,app,ids,states);
 ASSERT (SELECT estimated_rarity IS NULL AND base_status_xp=0.5 FROM public.steam_completion_awards WHERE user_id=u), 'Unavailable rarity stays null; preserve the existing XP floor for older clients';
 -- An empty available set grants nothing, even when all of it is archived.
 ASSERT public.apply_steam_completion_policy(app,ids,'{}','all_achievements',all_evidence,ids,false);
 PERFORM public.record_steam_completion(u,'76561190000011618',-11618,app,ids,states);
 ASSERT NOT EXISTS(SELECT 1 FROM public.steam_completion_awards WHERE user_id=u);
 ASSERT (SELECT pending_review_count=0 FROM public.get_steam_completion_stats(u)), 'An all-archived set needs no endless player recheck';
 ASSERT NOT has_function_privilege('authenticated','public.apply_steam_completion_policy(text,text[],text[],text,jsonb,text[],boolean)','EXECUTE');
 ASSERT NOT has_function_privilege('anon','public.apply_steam_completion_policy(text,text[],text[],text,jsonb,text[],boolean)','EXECUTE');
 ASSERT NOT has_table_privilege('anon','public.steam_completion_progress','SELECT');
 ASSERT NOT EXISTS(SELECT 1 FROM public.claim_steam_completion_review_job()), 'Legacy console-review worker is retired';
END $$;
SELECT 'Native Steam completion assertions passed' result;
ROLLBACK;
