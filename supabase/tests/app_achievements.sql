-- Rollback-only regression tests; can also be appended to the migration's
-- transaction before its COMMIT to validate the complete repair atomically.
BEGIN;
SET LOCAL statement_timeout='60s';
DO $$ DECLARE r record; BEGIN
 ASSERT (SELECT count(*)=133 FROM statusxp_private.app_achievement_rules),'All 133 catalog entries must have rules';
 ASSERT NOT EXISTS(SELECT 1 FROM statusxp_private.app_achievement_candidates('{}')),'Missing metrics must never award';
 FOR r IN SELECT * FROM statusxp_private.app_achievement_rules LOOP
  ASSERT EXISTS(SELECT 1 FROM statusxp_private.app_achievement_candidates(jsonb_build_object(r.metric,r.threshold)) c WHERE c.achievement_id=r.achievement_id),'Exact threshold must award '||r.achievement_id;
  ASSERT NOT EXISTS(SELECT 1 FROM statusxp_private.app_achievement_candidates(jsonb_build_object(r.metric,r.threshold-1)) c WHERE c.achievement_id=r.achievement_id),'Below threshold must not award '||r.achievement_id;
 END LOOP;
END $$;

INSERT INTO auth.users(id,email,raw_user_meta_data) VALUES
 ('00000000-0000-4000-8000-000000009941','app-achievement-9941@statusxp.invalid','{}');
INSERT INTO public.games(platform_id,platform_game_id,name) VALUES
 (1,'app-ach-test-bulk','App Achievement Bulk'),
 (1,'app-ach-test-match','App Achievement Match'),
 (2,'app-ach-test-match','App Achievement Match'),
 (10,'app-ach-test-match','App Achievement Match'),
 (4,'app-ach-test-match','App Achievement Match'),
 (4,'app-ach-test-other','App Achievement Match Remastered');
INSERT INTO public.achievements(platform_id,platform_game_id,platform_achievement_id,name,base_status_xp,metadata)
 SELECT 1,'app-ach-test-bulk',i::text,'Trophy '||i,10,'{"psn_trophy_type":"bronze"}'::jsonb FROM generate_series(1,1001) i;
INSERT INTO public.achievements(platform_id,platform_game_id,platform_achievement_id,name,base_status_xp,score_value,metadata,is_platinum) VALUES
 (1,'app-ach-test-match','1','Platinum',10,0,'{"psn_trophy_type":"platinum"}',true),
 (2,'app-ach-test-match','1','Bronze',10,0,'{"psn_trophy_type":"bronze"}',false),
 (10,'app-ach-test-match','1','Xbox A',10,25,'{}',false),
 (10,'app-ach-test-match','2','Xbox B',10,50,'{}',false),
 (4,'app-ach-test-match','1','Steam A',10,0,'{}',false),
 (4,'app-ach-test-match','2','Steam B',10,0,'{}',false);
INSERT INTO public.user_achievements(user_id,platform_id,platform_game_id,platform_achievement_id,earned_at)
 SELECT '00000000-0000-4000-8000-000000009941',platform_id,platform_game_id,platform_achievement_id,'2026-01-02T12:00:00Z'
 FROM public.achievements WHERE platform_game_id LIKE 'app-ach-test-%'
 AND NOT(platform_id=10 AND platform_achievement_id='2');
-- One undated Xbox unlock plus an overlapping dated/undated observation.
INSERT INTO public.user_undated_achievements(user_id,platform_id,platform_game_id,platform_achievement_id,evidence_source) VALUES
 ('00000000-0000-4000-8000-000000009941',10,'app-ach-test-match','1','xbox_live'),
 ('00000000-0000-4000-8000-000000009941',10,'app-ach-test-match','2','xbox_live');
INSERT INTO public.user_progress(user_id,platform_id,platform_game_id,total_achievements)
 SELECT '00000000-0000-4000-8000-000000009941',platform_id,platform_game_id,
 CASE WHEN platform_game_id='app-ach-test-bulk' THEN 1002 WHEN platform_id=1 OR platform_id=10 OR platform_id=4 THEN 2 ELSE 1 END
 FROM public.games WHERE platform_game_id LIKE 'app-ach-test-%';

DO $$ DECLARE m jsonb; BEGIN
 m:=statusxp_private.app_achievement_metrics('00000000-0000-4000-8000-000000009941');
 ASSERT (m->>'psn_total')::int=1003,'Totals must include more than 1000 records';
 ASSERT (m->>'xbox_total')::int=2,'Count undated unlocks once, without double-counting dated evidence';
 ASSERT (m->>'xbox_gamerscore')::int=75,'Gamerscore includes verified undated Xbox 360 unlocks';
 ASSERT (m->>'steam_total')::int=2 AND (m->>'psn_platinum')::int=1;
 ASSERT (m->>'xbox_complete')::int=1 AND (m->>'steam_perfect')::int=1,'Completion counts use all platform variants';
 ASSERT (m->>'total_unlocks')::int=1007 AND (m->>'total_games')::int=6;
 ASSERT (m->>'statusxp')::bigint=(SELECT COALESCE(sum(statusxp_effective),0) FROM public.calculate_statusxp_with_stacks('00000000-0000-4000-8000-000000009941')),'Match per-game integer scoring without using public leaderboard eligibility';
 ASSERT (m->>'completed_games')::int=3,'Incomplete definition sets and zero-trophy games must not count as complete';
 ASSERT (m->>'same_day_platforms')::int=3;
 ASSERT (m->>'same_game_complete_platforms')::int=3 AND (m->>'same_game_mastery_platforms')::int=3;
END $$;

SAVEPOINT date_evidence;
UPDATE public.user_achievements SET earned_at='2026-01-03T00:00:00Z'
 WHERE user_id='00000000-0000-4000-8000-000000009941' AND platform_id=10;
DO $$ BEGIN
 ASSERT (statusxp_private.app_achievement_metrics('00000000-0000-4000-8000-000000009941')->>'same_day_platforms')::int=2,'Unknown dates cannot fabricate a same-day award';
END $$;
ROLLBACK TO SAVEPOINT date_evidence;

SAVEPOINT edition_evidence;
UPDATE public.games SET name='App Achievement Match Remastered' WHERE platform_id=4 AND platform_game_id='app-ach-test-match';
DO $$ BEGIN
 ASSERT (statusxp_private.app_achievement_metrics('00000000-0000-4000-8000-000000009941')->>'same_game_complete_platforms')::int=2,'Remasters/editions must remain distinct';
END $$;
ROLLBACK TO SAVEPOINT edition_evidence;

SAVEPOINT family_evidence;
DELETE FROM public.user_achievements WHERE user_id='00000000-0000-4000-8000-000000009941' AND platform_id IN(4,10);
DELETE FROM public.user_undated_achievements WHERE user_id='00000000-0000-4000-8000-000000009941';
DO $$ BEGIN
 ASSERT (statusxp_private.app_achievement_metrics('00000000-0000-4000-8000-000000009941')->>'same_game_complete_platforms')::int=1,'PS4 and PS5 must count as one platform family';
END $$;
ROLLBACK TO SAVEPOINT family_evidence;

DO $$ DECLARE n integer; BEGIN
 SELECT count(*) INTO n FROM statusxp_private.reconcile_app_achievements('00000000-0000-4000-8000-000000009941');
 ASSERT n>0;
 ASSERT EXISTS(SELECT 1 FROM public.user_meta_achievements WHERE user_id='00000000-0000-4000-8000-000000009941' AND achievement_id='psn_1000_trophies');
END $$;
UPDATE public.user_meta_achievements SET unlocked_at='2020-01-01',custom_title='Keep my title'
 WHERE user_id='00000000-0000-4000-8000-000000009941' AND achievement_id='psn_first_trophy';
DO $$ BEGIN
 ASSERT (SELECT count(*)=0 FROM statusxp_private.reconcile_app_achievements('00000000-0000-4000-8000-000000009941')),'Repeat checks must not re-award';
 ASSERT EXISTS(SELECT 1 FROM public.user_meta_achievements WHERE user_id='00000000-0000-4000-8000-000000009941' AND achievement_id='psn_first_trophy' AND custom_title='Keep my title' AND unlocked_at='2020-01-01'),'Preserve existing dates and custom titles';
END $$;

-- Every successful platform completion queues a server check independently of
-- whether the client remains open. Status/progress polling must not requeue.
DELETE FROM statusxp_private.app_achievement_check_jobs WHERE user_id='00000000-0000-4000-8000-000000009941';
DO $$ DECLARE platform text; BEGIN
 FOREACH platform IN ARRAY ARRAY['psn','xbox','steam'] LOOP
  EXECUTE format('UPDATE public.profiles_private SET %I=''success'',%I=clock_timestamp() WHERE id=$1',platform||'_sync_status','last_'||platform||'_sync_at') USING '00000000-0000-4000-8000-000000009941'::uuid;
  ASSERT EXISTS(SELECT 1 FROM statusxp_private.app_achievement_check_jobs WHERE user_id='00000000-0000-4000-8000-000000009941');
  DELETE FROM statusxp_private.app_achievement_check_jobs WHERE user_id='00000000-0000-4000-8000-000000009941';
 END LOOP;
END $$;
UPDATE public.profiles_private SET psn_sync_progress=99 WHERE id='00000000-0000-4000-8000-000000009941';
DO $$ BEGIN
 ASSERT NOT EXISTS(SELECT 1 FROM statusxp_private.app_achievement_check_jobs WHERE user_id='00000000-0000-4000-8000-000000009941');
END $$;

-- A transient award write failure stays durable and retries successfully.
UPDATE statusxp_private.app_achievement_check_jobs SET next_attempt_at=now()+interval '1 day';
DELETE FROM public.user_meta_achievements WHERE user_id='00000000-0000-4000-8000-000000009941' AND achievement_id='psn_first_trophy';
CREATE FUNCTION statusxp_private.test_fail_app_award() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF NEW.user_id='00000000-0000-4000-8000-000000009941' THEN RAISE EXCEPTION 'Simulated temporary write failure'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER test_fail_app_award BEFORE INSERT ON public.user_meta_achievements FOR EACH ROW EXECUTE FUNCTION statusxp_private.test_fail_app_award();
INSERT INTO statusxp_private.app_achievement_check_jobs(user_id) VALUES('00000000-0000-4000-8000-000000009941');
DO $$ BEGIN
 ASSERT statusxp_private.drain_app_achievement_checks(1)=0;
 ASSERT EXISTS(SELECT 1 FROM statusxp_private.app_achievement_check_jobs WHERE user_id='00000000-0000-4000-8000-000000009941' AND attempts=1 AND last_error IS NOT NULL AND next_attempt_at>now()),'Failed checks must remain queued';
END $$;
DROP TRIGGER test_fail_app_award ON public.user_meta_achievements;
DROP FUNCTION statusxp_private.test_fail_app_award();
UPDATE statusxp_private.app_achievement_check_jobs SET next_attempt_at=now() WHERE user_id='00000000-0000-4000-8000-000000009941';
DO $$ BEGIN
 ASSERT statusxp_private.drain_app_achievement_checks(1)=1;
 ASSERT NOT EXISTS(SELECT 1 FROM statusxp_private.app_achievement_check_jobs WHERE user_id='00000000-0000-4000-8000-000000009941');
END $$;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000009941',true),set_config('request.jwt.claim.role','authenticated',true);
DO $$ BEGIN
 ASSERT (SELECT count(*)=0 FROM public.reconcile_app_achievements('00000000-0000-4000-8000-000000009941'));
 ASSERT NOT public.unlock_achievement_if_new('00000000-0000-4000-8000-000000009941','psn_10000_trophies','2000-01-01'),'Compatibility RPC cannot fabricate awards';
 BEGIN PERFORM public.reconcile_app_achievements('00000000-0000-4000-8000-000000009942'); RAISE EXCEPTION 'Cross-user award allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM statusxp_private.app_achievement_metrics('00000000-0000-4000-8000-000000009942'); RAISE EXCEPTION 'Private metrics exposed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
ROLLBACK;
