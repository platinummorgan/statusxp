BEGIN;
SET LOCAL statement_timeout='120s';
INSERT INTO auth.users(id,email,raw_user_meta_data) VALUES
 ('00000000-0000-4000-8000-000000011516','mythic-11516@statusxp.invalid','{"display_name":"Mythic fixture"}');
UPDATE public.profiles_private SET show_on_leaderboard=true,xbox_xuid='mythic-fixture-xuid',xbox_gamertag='Mythic fixture'
 WHERE id='00000000-0000-4000-8000-000000011516';
INSERT INTO public.xbox_sync_logs(id,user_id,sync_type,status,started_at)
 VALUES(-11516,'00000000-0000-4000-8000-000000011516','full','syncing',now());
INSERT INTO public.games(platform_id,platform_game_id,name) VALUES
 (11,'mythic-fixture-11516','Mythic fixture'),(10,'mythic-fixture-legacy-11516','Legacy fixture');
INSERT INTO public.achievements(platform_id,platform_game_id,platform_achievement_id,name,rarity_global,include_in_score,rarity_multiplier)
 VALUES(11,'mythic-fixture-11516','1','Rare base',0.1,true,1),
 (11,'mythic-fixture-11516','2','Common base',50,true,1),
 (11,'mythic-fixture-11516','3','Added DLC',0,true,1);
INSERT INTO public.user_progress(user_id,platform_id,platform_game_id,current_score,achievements_earned,total_achievements)
 VALUES('00000000-0000-4000-8000-000000011516',11,'mythic-fixture-11516',1000,2,3);
INSERT INTO public.user_achievements(user_id,platform_id,platform_game_id,platform_achievement_id,earned_at)
 VALUES('00000000-0000-4000-8000-000000011516',11,'mythic-fixture-11516','1',now()),
 ('00000000-0000-4000-8000-000000011516',11,'mythic-fixture-11516','2',now());
DO $$
DECLARE u uuid:='00000000-0000-4000-8000-000000011516'; d jsonb;
BEGIN
 ASSERT (SELECT mythic_count IS NULL AND NOT mythics_synced FROM public.get_xbox_mythic_stats(u)),
   'Unsynced must be unknown, not a confirmed zero';
 PERFORM public.mark_xbox_mythics_synced(u,'mythic-fixture-xuid',-11516);
 ASSERT (SELECT mythic_count=0 AND mythics_synced FROM public.get_xbox_mythic_stats(u)),
   'Confirmed zero must be distinguishable from unsynced';
 PERFORM public.record_xbox_mythic(u,'mythic-fixture-xuid',-11516,11,'mythic-fixture-11516',false,NULL);
 ASSERT EXISTS(SELECT 1 FROM public.leaderboard_refresh_jobs WHERE user_id=u AND kind='statusxp'),
   'New completion potential must refresh owners who have not earned a Mythic';
 d:=jsonb_build_object('required_ids',jsonb_build_array('1','2'),'membership_revision','fixture-v1',
   'estimated_rarity',0.1,'completed_at',now(),'source','xbox_live_contract_6');
 PERFORM public.record_xbox_mythic(u,'mythic-fixture-xuid',-11516,11,'mythic-fixture-11516',true,d);
 PERFORM public.record_xbox_mythic(u,'mythic-fixture-xuid',-11516,11,'mythic-fixture-11516',true,d);
 PERFORM public.record_xbox_mythic(u,'mythic-fixture-xuid',-11516,11,'mythic-fixture-11516',false,NULL);
 ASSERT (SELECT count(*)=1 AND min(base_status_xp)=57.83 FROM public.xbox_mythic_awards WHERE user_id=u),
   'Retry/false responses must preserve exactly one native award with five-times rarity component';
 ASSERT (SELECT mythic_count=1 FROM public.get_xbox_mythic_stats(u)), 'Dashboard count must match earned awards';
 ASSERT (SELECT mythic_count=1 FROM public.get_xbox_mythic_leaderboard(1000,0) WHERE user_id=u),
   'Leaderboard must use Mythics, not Gamerscore';
 ASSERT (SELECT period_gain=1 FROM public.get_xbox_mythic_period_leaderboard('weekly',1000,0) WHERE user_id=u),
   'Weekly gain must count native Mythics with genuine completion times';
 ASSERT (SELECT sum(period_gain)=1 FROM public.get_user_seasonal_game_breakdown(u,'xbox','weekly',200,0)),
   'Xbox seasonal breakdown must reconcile with the Mythic board';
 ASSERT (SELECT statusxp_effective=72 AND achievements_earned=2 FROM public.calculate_statusxp_with_stacks(u)),
   'Round combined game XP once without increasing ordinary achievement count';
 PERFORM set_config('request.jwt.claims','{"role":"service_role"}',true);
 ASSERT (SELECT total_statusxp=72 FROM public.get_dashboard_games(u)),
   'Dashboard game XP must include the Mythic before rounding';
 ASSERT (SELECT total_statusxp=72 FROM public.get_user_grouped_games(u)),
   'Library game XP must include the Mythic before rounding';
 ASSERT (SELECT count(*)=2 FROM public.user_achievement_unlocks WHERE user_id=u),
   'A Mythic must not become an ordinary unlock';
 PERFORM public.refresh_statusxp_leaderboard_for_user(u);
 ASSERT (SELECT total_statusxp=72 AND potential_statusxp=84 AND total_game_entries=1 FROM public.leaderboard_cache WHERE user_id=u),
   'Per-user refresh must include completion earned and potential XP exactly once';
 PERFORM public.record_xbox_mythic(u,'mythic-fixture-xuid',-11516,10,'mythic-fixture-legacy-11516',true,NULL);
 ASSERT (SELECT earned_at IS NULL AND base_status_xp=0.5 FROM public.xbox_mythic_awards
   WHERE user_id=u AND platform_id=10), 'Legacy native Mythics retain unknown rarity/date without invented timestamps';
 ASSERT (SELECT period_gain=1 AND mythic_count=2 FROM public.get_xbox_mythic_period_leaderboard('weekly',1000,0) WHERE user_id=u),
   'Undated historical imports count all-time only';
 BEGIN
   PERFORM public.record_xbox_mythic(u,'different-account',-11516,11,'mythic-fixture-11516',true,d);
   RAISE EXCEPTION 'Account binding was not enforced';
 EXCEPTION WHEN raise_exception THEN
   IF SQLERRM='Account binding was not enforced' THEN RAISE; END IF;
 END;
 ASSERT NOT has_function_privilege('authenticated','public.record_xbox_mythic(uuid,text,bigint,bigint,text,boolean,jsonb)','EXECUTE'),
   'Clients must not grant themselves Mythics';
 ASSERT NOT has_table_privilege('anon','public.user_xbox_mythics','SELECT'), 'Provider identities remain private';
 ASSERT NOT has_table_privilege('authenticated','public.xbox_mythic_catalog','TRUNCATE'), 'Catalog cannot be cleared by clients';
 UPDATE public.profiles_private SET xbox_xuid=NULL WHERE id=u;
 ASSERT NOT EXISTS(SELECT 1 FROM public.xbox_mythic_awards WHERE user_id=u), 'Relinking must not transfer another account awards';
 ASSERT (SELECT mythic_count IS NULL FROM public.get_xbox_mythic_stats(u)), 'Relinking resets known sync state';
 UPDATE public.profiles_private SET xbox_xuid='mythic-fixture-xuid' WHERE id=u;
END;
$$;
SELECT public.refresh_statusxp_leaderboard();
DO $$ BEGIN
 ASSERT (SELECT total_statusxp=73 AND potential_statusxp=84 AND total_game_entries=2
 FROM public.leaderboard_cache WHERE user_id='00000000-0000-4000-8000-000000011516'),
 'Full refresh must match canonical totals, including a dated and an undated Mythic';
END; $$;
SELECT 'Xbox Mythic completion assertions passed' result;
ROLLBACK;
