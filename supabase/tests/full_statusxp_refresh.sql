BEGIN;
SET LOCAL statement_timeout='60s';
INSERT INTO auth.users(id,email,raw_user_meta_data) VALUES('00000000-0000-4000-8000-000000009951','score-refresh-9951@statusxp.invalid','{"display_name":"Score fixture"}');
INSERT INTO public.games(platform_id,platform_game_id,name) VALUES
 (1,'score-refresh-9951-main','Score fixture'),(1,'score-refresh-9951-round','Round fixture'),(2,'score-refresh-9951-round','Round fixture');
INSERT INTO public.achievements(platform_id,platform_game_id,platform_achievement_id,name,base_status_xp,rarity_multiplier,include_in_score,rarity_global) VALUES
 (1,'score-refresh-9951-main','1','Earned one',10,1,true,0),
 (1,'score-refresh-9951-main','2','Earned two',20,2,true,0),
 (1,'score-refresh-9951-main','3','Unearned',5,1,true,0),
 (1,'score-refresh-9951-main','4','Excluded',1000,1,false,0),
 (1,'score-refresh-9951-round','1','Round',0.6,1.2,true,NULL),
 (2,'score-refresh-9951-round','1','Round',0.6,1.2,true,NULL);
INSERT INTO public.user_achievements(user_id,platform_id,platform_game_id,platform_achievement_id,earned_at) VALUES
 ('00000000-0000-4000-8000-000000009951',1,'score-refresh-9951-main','1',now()),
 ('00000000-0000-4000-8000-000000009951',1,'score-refresh-9951-main','2',now()),
 ('00000000-0000-4000-8000-000000009951',1,'score-refresh-9951-main','4',now()),
 ('00000000-0000-4000-8000-000000009951',1,'score-refresh-9951-round','1',now()),
 ('00000000-0000-4000-8000-000000009951',2,'score-refresh-9951-round','1',now());
SELECT public.refresh_statusxp_leaderboard();
DO $$ BEGIN
 ASSERT (SELECT total_statusxp=38 AND potential_statusxp=37 AND total_game_entries=3 FROM public.leaderboard_cache WHERE user_id='00000000-0000-4000-8000-000000009951'),'Each earned score counts once; round per game; include potential once per platform/game';
 ASSERT (SELECT SUM(statusxp_effective)=38 FROM public.calculate_statusxp_with_stacks('00000000-0000-4000-8000-000000009951')),'Canonical calculation must agree';
END $$;
DELETE FROM public.user_achievements WHERE user_id='00000000-0000-4000-8000-000000009951';
SELECT public.refresh_statusxp_leaderboard_for_user('00000000-0000-4000-8000-000000009951');
DO $$ BEGIN ASSERT NOT EXISTS(SELECT 1 FROM public.leaderboard_cache WHERE user_id='00000000-0000-4000-8000-000000009951'),'Zero source data must remove an old positive score'; END $$;
INSERT INTO public.leaderboard_cache(user_id,total_statusxp,total_game_entries) VALUES('00000000-0000-4000-8000-000000009951',999,1);
UPDATE public.profiles_private SET show_on_leaderboard=false WHERE id='00000000-0000-4000-8000-000000009951';
SELECT public.refresh_statusxp_leaderboard();
DO $$ BEGIN
 ASSERT NOT EXISTS(SELECT 1 FROM public.leaderboard_cache WHERE user_id='00000000-0000-4000-8000-000000009951'),'Full refresh removes stale/ineligible rows';
 ASSERT NOT has_function_privilege('anon','public.auto_refresh_all_leaderboards()','EXECUTE'),'Maintenance cannot be anonymous';
END $$;
SELECT 'Full and per-user StatusXP refresh regression assertions passed' result;
ROLLBACK;
