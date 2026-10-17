-- Apply directly using the project's manual migration process, never db push.
BEGIN;
SET LOCAL lock_timeout = '5s';

CREATE TABLE statusxp_private.app_achievement_rules (
 achievement_id text PRIMARY KEY REFERENCES public.meta_achievements(id),
 metric text NOT NULL,
 threshold bigint NOT NULL CHECK (threshold > 0)
);
REVOKE ALL ON statusxp_private.app_achievement_rules FROM PUBLIC,anon,authenticated,service_role;

-- Numeric milestones share rules; special achievements have explicit criteria.
INSERT INTO statusxp_private.app_achievement_rules
SELECT id,
 CASE
  WHEN id ~ '^psn_[0-9]+_' THEN 'psn_' || CASE split_part(id,'_',3) WHEN 'trophies' THEN 'total' ELSE split_part(id,'_',3) END
  WHEN id ~ '^xbox_[0-9]+_' THEN 'xbox_' || CASE split_part(id,'_',3) WHEN 'achievements' THEN 'total' WHEN 'gs' THEN 'gamerscore' ELSE split_part(id,'_',3) END
  WHEN id ~ '^steam_[0-9]+_' THEN 'steam_' || CASE split_part(id,'_',3) WHEN 'achievements' THEN 'total' ELSE split_part(id,'_',3) END
  WHEN id ~ '^cross_statusxp_[0-9]+$' THEN 'statusxp'
  WHEN id ~ '^cross_[0-9]+_unlocks$' THEN 'total_unlocks'
  WHEN id ~ '^cross_[0-9]+_games$' THEN 'total_games'
  WHEN id ~ '^cross_rare_[0-9]+_each$' THEN 'rare_each'
 END,
 (regexp_match(id,'([0-9]+)'))[1]::bigint
FROM public.meta_achievements
WHERE id ~ '^(psn_[0-9]+_(trophies|bronze|silver|gold|platinum|rare)|xbox_[0-9]+_(achievements|gs|complete|rare)|steam_[0-9]+_(achievements|perfect|rare)|cross_statusxp_[0-9]+|cross_[0-9]+_(unlocks|games)|cross_rare_[0-9]+_each)$';
INSERT INTO statusxp_private.app_achievement_rules VALUES
 ('psn_first_trophy','psn_total',1),('xbox_first_unlock','xbox_total',1),('steam_first_unlock','steam_total',1),
 ('cross_platform_hopper','same_day_platforms',3),
 ('cross_triple_threat','unlocks_each',100),('cross_universal_gamer','unlocks_each',500),
 ('cross_platform_master','unlocks_each',1000),('cross_ecosystem_legend','unlocks_each',2500),
 ('cross_double_dip','same_game_complete_platforms',2),('cross_triple_play','same_game_complete_platforms',3),
 ('cross_triple_platinum','same_game_mastery_platforms',3),
 ('cross_collection_complete','completed_games',5),('cross_platform_complete','completed_games',10);
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.meta_achievements m LEFT JOIN statusxp_private.app_achievement_rules r ON r.achievement_id=m.id WHERE r.achievement_id IS NULL)
 THEN RAISE EXCEPTION 'App achievement catalog contains unmapped criteria'; END IF;
END $$;

CREATE FUNCTION statusxp_private.app_achievement_metrics(p_user_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SET search_path='' AS $$
WITH earned AS MATERIALIZED (
 SELECT u.platform_id,u.platform_game_id,u.earned_at,
  CASE WHEN u.platform_id IN(1,2,5,9) THEN 'psn' WHEN u.platform_id IN(10,11,12) THEN 'xbox' ELSE 'steam' END family,
  CASE WHEN a.is_platinum THEN 'platinum' ELSE a.metadata->>'psn_trophy_type' END trophy_type,
  a.rarity_global,a.score_value,a.include_in_score,a.base_status_xp,a.rarity_multiplier
 FROM public.user_achievement_unlocks u
 JOIN public.achievements a USING(platform_id,platform_game_id,platform_achievement_id)
 WHERE u.user_id=p_user_id AND u.platform_id IN(1,2,5,9,10,11,12,4)
), per_family AS (
 SELECT f.family,count(e.platform_id) total,
  count(*) FILTER(WHERE e.rarity_global>=0 AND e.rarity_global<10) rare,
  COALESCE(sum(e.score_value),0) gamerscore
 FROM (VALUES('psn'),('xbox'),('steam')) f(family) LEFT JOIN earned e USING(family) GROUP BY f.family
), earned_games AS MATERIALIZED (
 SELECT platform_id,platform_game_id,family,count(*) earned_count,
  bool_or(trophy_type='platinum') platinum,
  COALESCE(sum(base_status_xp*COALESCE(rarity_multiplier,1)) FILTER(WHERE include_in_score),0)::integer earned_xp
 FROM earned GROUP BY platform_id,platform_game_id,family
), library AS MATERIALIZED (
 SELECT platform_id,platform_game_id FROM public.user_progress
 WHERE user_id=p_user_id AND platform_id IN(1,2,5,9,10,11,12,4)
 UNION SELECT platform_id,platform_game_id FROM earned_games
), definitions AS (
 SELECT l.platform_id,l.platform_game_id,count(a.platform_achievement_id) total
 FROM library l LEFT JOIN public.achievements a USING(platform_id,platform_game_id)
 GROUP BY l.platform_id,l.platform_game_id
), game_state AS MATERIALIZED (
 SELECT g.platform_id,g.platform_game_id,
  CASE WHEN g.platform_id IN(1,2,5,9) THEN 'psn' WHEN g.platform_id IN(10,11,12) THEN 'xbox' ELSE 'steam' END family,
  -- Full titles only: edition/remaster labels stay distinct; PS4/PS5 are one family.
  NULLIF(regexp_replace(lower(btrim(translate(g.name,'™®©',''))),'\s+',' ','g'),'') game_key,
  d.total>0 AND COALESCE(e.earned_count,0)>=greatest(d.total,COALESCE(p.total_achievements,0)) complete,
  COALESCE(e.platinum,false) platinum,COALESCE(e.earned_xp,0) earned_xp
 FROM library l JOIN public.games g USING(platform_id,platform_game_id)
 JOIN definitions d USING(platform_id,platform_game_id)
 LEFT JOIN earned_games e USING(platform_id,platform_game_id)
 LEFT JOIN public.user_progress p ON p.user_id=p_user_id AND p.platform_id=l.platform_id AND p.platform_game_id=l.platform_game_id
), same_game AS (
 SELECT game_key,count(DISTINCT family) FILTER(WHERE complete) complete_platforms,
  count(DISTINCT family) FILTER(WHERE CASE WHEN family='psn' THEN platinum ELSE complete END) mastery_platforms
 FROM game_state WHERE game_key IS NOT NULL GROUP BY game_key
), per_day AS (
 -- Unknown unlock dates cannot establish a same-day award. Days use UTC,
 -- matching the existing engagement/leaderboard date convention.
 SELECT (earned_at AT TIME ZONE 'UTC')::date AS earned_day,count(DISTINCT family) platforms
 FROM earned WHERE earned_at IS NOT NULL GROUP BY 1
), family_metrics AS (
 SELECT jsonb_object_agg(family||'_total',total) || jsonb_object_agg(family||'_rare',rare)
  || jsonb_object_agg(family||'_gamerscore',gamerscore) metrics FROM per_family
)
SELECT metrics || jsonb_build_object(
 'psn_bronze',(SELECT count(*) FROM earned WHERE family='psn' AND trophy_type='bronze'),
 'psn_silver',(SELECT count(*) FROM earned WHERE family='psn' AND trophy_type='silver'),
 'psn_gold',(SELECT count(*) FROM earned WHERE family='psn' AND trophy_type='gold'),
 'psn_platinum',(SELECT count(*) FROM earned WHERE family='psn' AND trophy_type='platinum'),
 'xbox_complete',(SELECT count(*) FROM game_state WHERE family='xbox' AND complete),
 'steam_perfect',(SELECT count(*) FROM game_state WHERE family='steam' AND complete),
 'total_unlocks',(SELECT count(*) FROM earned),'total_games',(SELECT count(*) FROM game_state),
 'statusxp',(SELECT COALESCE(sum(earned_xp),0) FROM game_state),
 'unlocks_each',(SELECT min(total) FROM per_family),'rare_each',(SELECT min(rare) FROM per_family),
 'same_day_platforms',(SELECT COALESCE(max(platforms),0) FROM per_day),
 'same_game_complete_platforms',(SELECT COALESCE(max(complete_platforms),0) FROM same_game),
 'same_game_mastery_platforms',(SELECT COALESCE(max(mastery_platforms),0) FROM same_game),
 'completed_games',(SELECT count(*) FROM game_state WHERE complete)
) FROM family_metrics;
$$;

CREATE FUNCTION statusxp_private.app_achievement_candidates(p_metrics jsonb)
RETURNS TABLE(achievement_id text) LANGUAGE sql STABLE SET search_path='' AS $$
 -- Prevent SQL-function inlining from recalculating history for every rule.
 WITH metrics AS MATERIALIZED (SELECT p_metrics AS value)
 SELECT r.achievement_id FROM statusxp_private.app_achievement_rules r CROSS JOIN metrics m
 WHERE COALESCE((m.value->>r.metric)::numeric,0)>=r.threshold;
$$;

CREATE FUNCTION statusxp_private.reconcile_app_achievements(p_user_id uuid)
RETURNS TABLE(achievement_id text) LANGUAGE sql SET search_path='' AS $$
 INSERT INTO public.user_meta_achievements(user_id,achievement_id,unlocked_at)
 SELECT p_user_id,c.achievement_id,now()
 FROM statusxp_private.app_achievement_candidates(statusxp_private.app_achievement_metrics(p_user_id)) c
 WHERE EXISTS(SELECT 1 FROM public.profiles_private p WHERE p.id=p_user_id AND p.merged_into_user_id IS NULL)
 ON CONFLICT(user_id,achievement_id) DO NOTHING RETURNING user_meta_achievements.achievement_id;
$$;

CREATE FUNCTION public.reconcile_app_achievements(p_user_id uuid DEFAULT auth.uid())
RETURNS TABLE(achievement_id text) LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF p_user_id IS NULL OR (auth.role() IS DISTINCT FROM 'service_role' AND (auth.uid() IS NULL OR auth.uid()<>p_user_id))
 THEN RAISE EXCEPTION 'Only your own app achievements can be checked' USING ERRCODE='42501'; END IF;
 RETURN QUERY SELECT * FROM statusxp_private.reconcile_app_achievements(p_user_id);
END $$;
REVOKE ALL ON FUNCTION public.reconcile_app_achievements(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.reconcile_app_achievements(uuid) TO authenticated,service_role;

-- Keep installed clients compatible, but validate awards using the same rules.
CREATE OR REPLACE FUNCTION public.unlock_achievement_if_new(p_user_id uuid,p_achievement_id text,p_unlocked_at timestamptz DEFAULT now())
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE awarded boolean;
BEGIN
 IF p_user_id IS NULL OR (auth.role() IS DISTINCT FROM 'service_role' AND (auth.uid() IS NULL OR auth.uid()<>p_user_id))
 THEN RAISE EXCEPTION 'Only your own app achievements can be checked' USING ERRCODE='42501'; END IF;
 WITH inserted AS (
  INSERT INTO public.user_meta_achievements(user_id,achievement_id,unlocked_at)
  SELECT p_user_id,c.achievement_id,now()
  FROM statusxp_private.app_achievement_candidates(statusxp_private.app_achievement_metrics(p_user_id)) c
  WHERE c.achievement_id=p_achievement_id
  ON CONFLICT(user_id,achievement_id) DO NOTHING RETURNING 1
 ) SELECT EXISTS(SELECT 1 FROM inserted) INTO awarded;
 RETURN awarded;
END $$;
REVOKE ALL ON FUNCTION public.unlock_achievement_if_new(uuid,text,timestamptz) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.unlock_achievement_if_new(uuid,text,timestamptz) TO authenticated,service_role;

-- Combined totals/library milestones apply even with only one linked platform.
UPDATE public.meta_achievements m SET required_platforms=ARRAY[]::text[]
FROM statusxp_private.app_achievement_rules r WHERE r.achievement_id=m.id
 AND r.metric IN('statusxp','total_unlocks','total_games','completed_games','same_game_complete_platforms')
 AND m.id<>'cross_triple_play';

CREATE TABLE statusxp_private.app_achievement_check_jobs (
 user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
 requested_at timestamptz NOT NULL DEFAULT now(),
 next_attempt_at timestamptz NOT NULL DEFAULT now(),
 attempts integer NOT NULL DEFAULT 0,last_error text
);
REVOKE ALL ON statusxp_private.app_achievement_check_jobs FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION statusxp_private.queue_app_achievement_check()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF TG_OP='UPDATE' THEN
  IF NEW.last_psn_sync_at IS NOT DISTINCT FROM OLD.last_psn_sync_at
   AND NEW.last_xbox_sync_at IS NOT DISTINCT FROM OLD.last_xbox_sync_at
   AND NEW.last_steam_sync_at IS NOT DISTINCT FROM OLD.last_steam_sync_at THEN RETURN NEW; END IF;
 END IF;
 IF NEW.last_psn_sync_at IS NOT NULL OR NEW.last_xbox_sync_at IS NOT NULL OR NEW.last_steam_sync_at IS NOT NULL THEN
  INSERT INTO statusxp_private.app_achievement_check_jobs(user_id) VALUES(NEW.user_id)
  ON CONFLICT(user_id) DO UPDATE SET requested_at=clock_timestamp(),next_attempt_at=now(),attempts=0,last_error=NULL;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER queue_app_achievement_check AFTER INSERT OR UPDATE ON public.profile_sync_notifications
 FOR EACH ROW EXECUTE FUNCTION statusxp_private.queue_app_achievement_check();

CREATE FUNCTION statusxp_private.drain_app_achievement_checks(p_limit integer DEFAULT 10)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE job record; processed integer:=0;
BEGIN
 FOR job IN SELECT user_id FROM statusxp_private.app_achievement_check_jobs
  WHERE next_attempt_at<=now() ORDER BY requested_at,user_id FOR UPDATE SKIP LOCKED LIMIT p_limit LOOP
  BEGIN
   PERFORM statusxp_private.reconcile_app_achievements(job.user_id);
   DELETE FROM statusxp_private.app_achievement_check_jobs WHERE user_id=job.user_id;
   processed:=processed+1;
  EXCEPTION WHEN OTHERS THEN
   UPDATE statusxp_private.app_achievement_check_jobs SET attempts=attempts+1,
    last_error='App achievement check failed ('||SQLSTATE||')',
    next_attempt_at=now()+make_interval(secs=>least(900,30*power(2,least(attempts,5)))::integer)
   WHERE user_id=job.user_id;
  END;
 END LOOP;
 RETURN processed;
END $$;

REVOKE ALL ON FUNCTION statusxp_private.app_achievement_metrics(uuid),statusxp_private.app_achievement_candidates(jsonb),
 statusxp_private.reconcile_app_achievements(uuid),statusxp_private.queue_app_achievement_check(),
 statusxp_private.drain_app_achievement_checks(integer) FROM PUBLIC,anon,authenticated,service_role;

-- Queue existing accounts for idempotent recovery; preserve unlock dates/titles.
INSERT INTO statusxp_private.app_achievement_check_jobs(user_id)
 SELECT p.id FROM public.profiles_private p WHERE p.merged_into_user_id IS NULL
 AND (EXISTS(SELECT 1 FROM public.user_progress u WHERE u.user_id=p.id)
  OR EXISTS(SELECT 1 FROM public.user_achievement_unlocks u WHERE u.user_id=p.id));
SELECT cron.schedule('app-achievement-checks','* * * * *','SELECT statusxp_private.drain_app_achievement_checks(10);');
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='user_meta_achievements') THEN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.user_meta_achievements;
 END IF;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;
