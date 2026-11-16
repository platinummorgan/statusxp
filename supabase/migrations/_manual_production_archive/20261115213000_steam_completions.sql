BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='120s';

CREATE TABLE public.steam_completion_catalog (
 platform_id bigint NOT NULL DEFAULT 4 CHECK(platform_id=4),
 platform_game_id text PRIMARY KEY,
 review_state text NOT NULL DEFAULT 'pending' CHECK(review_state IN('pending','verified','needs_review')),
 observed_ids text[] NOT NULL DEFAULT '{}',
 required_ids text[] NOT NULL DEFAULT '{}',
 excluded_ids text[] NOT NULL DEFAULT '{}',
 membership_revision text,
 evidence jsonb NOT NULL DEFAULT '{}',
 reviewed_at timestamptz,
 estimated_rarity numeric CHECK(estimated_rarity BETWEEN 0 AND 100),
 rarity_source text NOT NULL DEFAULT 'estimated_minimum_day_one_base_game',
 base_status_xp numeric(6,2) GENERATED ALWAYS AS
  (CASE WHEN estimated_rarity IS NULL THEN 0.5
    ELSE round(0.5+57.5*power(1-estimated_rarity/100.0,3),2) END) STORED,
 FOREIGN KEY(platform_id,platform_game_id) REFERENCES public.games ON DELETE CASCADE,
 CHECK(review_state<>'verified' OR (cardinality(required_ids)>0 AND membership_revision IS NOT NULL))
);
CREATE TABLE public.steam_completion_progress (
 user_id uuid NOT NULL REFERENCES auth.users ON DELETE CASCADE,
 platform_id bigint NOT NULL DEFAULT 4 CHECK(platform_id=4),
 platform_game_id text NOT NULL REFERENCES public.steam_completion_catalog ON DELETE CASCADE,
 source_steam_id text NOT NULL,
 membership_revision text,
 required_count integer NOT NULL DEFAULT 0,
 earned_count integer NOT NULL DEFAULT 0,
 is_complete boolean NOT NULL DEFAULT false,
 earned_at timestamptz,
 checked_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(user_id,platform_game_id),
 CHECK(earned_count>=0 AND earned_count<=required_count),
 CHECK(NOT is_complete OR (required_count>0 AND earned_count=required_count))
);
CREATE INDEX steam_completion_progress_catalog_idx ON public.steam_completion_progress(platform_game_id);
CREATE TABLE public.steam_completion_sync_state (
 user_id uuid PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
 source_steam_id text NOT NULL,synced_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.steam_completion_leaderboard_history (
 user_id uuid NOT NULL REFERENCES auth.users ON DELETE CASCADE,
 snapshot_at timestamptz NOT NULL DEFAULT now(),rank integer NOT NULL,completion_count bigint NOT NULL,
 PRIMARY KEY(user_id,snapshot_at)
);
ALTER TABLE public.steam_completion_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.steam_completion_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.steam_completion_sync_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.steam_completion_leaderboard_history ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.steam_completion_catalog,public.steam_completion_progress,
 public.steam_completion_sync_state,public.steam_completion_leaderboard_history FROM anon,authenticated;
CREATE POLICY steam_completion_catalog_read ON public.steam_completion_catalog FOR SELECT USING(true);
GRANT SELECT ON public.steam_completion_catalog TO anon,authenticated;
GRANT ALL ON public.steam_completion_catalog,public.steam_completion_progress,
 public.steam_completion_sync_state,public.steam_completion_leaderboard_history TO service_role;

CREATE VIEW public.steam_completion_awards WITH(security_barrier=true) AS
SELECT s.user_id,s.platform_id,s.platform_game_id,s.earned_at,c.estimated_rarity,c.rarity_source,
 c.base_status_xp,c.membership_revision
FROM public.steam_completion_progress s JOIN public.steam_completion_catalog c USING(platform_game_id)
JOIN public.profiles_private p ON p.id=s.user_id AND p.steam_id::text=s.source_steam_id
WHERE s.is_complete AND c.review_state='verified' AND s.membership_revision=c.membership_revision
 AND p.merged_into_user_id IS NULL
 AND (p.show_on_leaderboard OR p.id=auth.uid() OR auth.role()='service_role' OR current_user='postgres');
GRANT SELECT ON public.steam_completion_awards TO anon,authenticated,service_role;
CREATE VIEW public.statusxp_completion_awards WITH(security_invoker=true) AS
 SELECT * FROM public.xbox_mythic_awards UNION ALL SELECT * FROM public.steam_completion_awards;
GRANT SELECT ON public.statusxp_completion_awards TO anon,authenticated,service_role;

CREATE FUNCTION public.assert_steam_completion_sync(p_user_id uuid,p_steam_id text,p_sync_log_id bigint)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.profiles_private p WHERE p.id=p_user_id AND p.steam_id::text=p_steam_id
   AND p.merged_into_user_id IS NULL AND p.steam_sync_status='syncing')
 OR NOT EXISTS(SELECT 1 FROM public.steam_sync_logs l WHERE l.id=p_sync_log_id AND l.user_id=p_user_id
   AND l.status IN('pending','syncing')) THEN RAISE EXCEPTION 'Steam account or sync session changed'; END IF;
END; $$;

-- The trusted review workflow supplies a complete original-day-one classification.
-- Group zero alone is insufficient evidence: Steam defaults unassigned DLC into it.
CREATE FUNCTION public.review_steam_completion_set(p_app_id text,p_required_ids text[],p_excluded_ids text[],p_evidence jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_all text[];v_required text[];v_excluded text[];
BEGIN
 SELECT array_agg(platform_achievement_id ORDER BY platform_achievement_id) INTO v_all
 FROM public.achievements WHERE platform_id=4 AND platform_game_id=p_app_id;
 SELECT array_agg(DISTINCT id ORDER BY id) INTO v_required FROM unnest(p_required_ids) id;
 SELECT COALESCE(array_agg(DISTINCT id ORDER BY id),'{}') INTO v_excluded FROM unnest(p_excluded_ids) id;
 IF cardinality(v_required) IS NULL OR cardinality(v_required)=0 OR v_all IS NULL
   OR NOT v_required<@v_all OR NOT v_excluded<@v_all OR v_required&&v_excluded
   OR NOT v_all<@(v_required||v_excluded) OR jsonb_typeof(p_evidence) IS DISTINCT FROM 'object'
   OR p_evidence->>'scope' IS DISTINCT FROM 'day_one_base_game'
   OR jsonb_array_length(COALESCE(p_evidence->'sources','[]'))=0 THEN
   RAISE EXCEPTION 'A nonempty complete day-one classification with source evidence is required';
 END IF;
 INSERT INTO public.steam_completion_catalog(platform_game_id,observed_ids,required_ids,excluded_ids,
   review_state,membership_revision,evidence,reviewed_at)
 VALUES(p_app_id,v_all,v_required,v_excluded,'verified',md5(to_jsonb(v_required)::text),p_evidence,now())
 ON CONFLICT(platform_game_id) DO UPDATE SET observed_ids=EXCLUDED.observed_ids,
   required_ids=EXCLUDED.required_ids,excluded_ids=EXCLUDED.excluded_ids,review_state='verified',
   membership_revision=EXCLUDED.membership_revision,evidence=EXCLUDED.evidence,reviewed_at=now(),estimated_rarity=NULL;
 UPDATE public.steam_completion_catalog c SET estimated_rarity=(
   SELECT CASE WHEN count(*)=cardinality(v_required) AND count(rarity_global)=cardinality(v_required)
     THEN min(rarity_global) ELSE NULL END FROM public.achievements a
   WHERE a.platform_id=4 AND a.platform_game_id=p_app_id AND a.platform_achievement_id=ANY(v_required))
 WHERE c.platform_game_id=p_app_id;
END; $$;

CREATE FUNCTION public.record_steam_completion(p_user_id uuid,p_steam_id text,p_sync_log_id bigint,
 p_app_id text,p_schema_names text[],p_player_state jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE c public.steam_completion_catalog%ROWTYPE;v_count integer;v_earned integer;
 v_complete boolean:=false;v_time timestamptz;v_rarity numeric;v_schema text[];
BEGIN
 PERFORM public.assert_steam_completion_sync(p_user_id,p_steam_id,p_sync_log_id);
 SELECT array_agg(DISTINCT id ORDER BY id) INTO v_schema FROM unnest(p_schema_names) id;
 IF cardinality(v_schema) IS NULL OR cardinality(v_schema)=0 OR cardinality(v_schema)<>cardinality(p_schema_names)
   OR jsonb_typeof(p_player_state) IS DISTINCT FROM 'array'
   OR EXISTS(SELECT 1 FROM jsonb_array_elements(p_player_state) s
     WHERE s->>'apiname' IS NULL OR NOT (s->>'apiname'=ANY(v_schema)) OR s->>'achieved' IS NULL OR s->>'achieved' NOT IN('0','1'))
   OR (SELECT count(DISTINCT s->>'apiname') FROM jsonb_array_elements(p_player_state) s)<>jsonb_array_length(p_player_state)
   THEN RAISE EXCEPTION 'Incomplete Steam schema or player response'; END IF;
 INSERT INTO public.steam_completion_catalog(platform_game_id,observed_ids) VALUES(p_app_id,v_schema)
   ON CONFLICT DO NOTHING;
 SELECT * INTO c FROM public.steam_completion_catalog WHERE platform_game_id=p_app_id FOR UPDATE;
 IF c.review_state='verified' AND NOT c.required_ids<@v_schema THEN
   UPDATE public.steam_completion_catalog SET review_state='needs_review',observed_ids=v_schema
    WHERE platform_game_id=p_app_id; c.review_state:='needs_review';
 ELSIF c.review_state='verified' THEN
   -- New IDs seen after an exhaustive review are later additions, not day-one requirements.
   UPDATE public.steam_completion_catalog SET observed_ids=v_schema,
     excluded_ids=ARRAY(SELECT DISTINCT id FROM unnest(c.excluded_ids||v_schema) id WHERE NOT id=ANY(c.required_ids) ORDER BY id)
    WHERE platform_game_id=p_app_id;
 ELSE UPDATE public.steam_completion_catalog SET observed_ids=v_schema WHERE platform_game_id=p_app_id;
 END IF;
 IF c.review_state='verified' THEN
   v_count:=cardinality(c.required_ids);
   IF (SELECT count(*) FROM jsonb_array_elements(p_player_state) s WHERE s->>'apiname'=ANY(c.required_ids))<>v_count
     THEN RAISE EXCEPTION 'Steam player response lacks required achievement states'; END IF;
   SELECT count(*)::integer INTO v_earned FROM jsonb_array_elements(p_player_state) s
     WHERE s->>'apiname'=ANY(c.required_ids) AND s->>'achieved'='1';
   v_complete:=v_earned=v_count;
   IF v_complete THEN
     -- Every required date must be valid; a zero/sentinel never becomes the sync time.
     SELECT CASE WHEN count(*) FILTER(WHERE (s->>'unlocktime')::numeric>0
       AND (s->>'unlocktime')::numeric<=extract(epoch FROM now()))=v_count
       THEN to_timestamp(max((s->>'unlocktime')::double precision)) ELSE NULL END INTO v_time
     FROM jsonb_array_elements(p_player_state) s WHERE s->>'apiname'=ANY(c.required_ids);
   END IF;
   SELECT CASE WHEN count(*)=v_count AND count(rarity_global)=v_count THEN min(rarity_global) ELSE NULL END
     INTO v_rarity FROM public.achievements WHERE platform_id=4 AND platform_game_id=p_app_id
     AND platform_achievement_id=ANY(c.required_ids);
   UPDATE public.steam_completion_catalog SET estimated_rarity=v_rarity WHERE platform_game_id=p_app_id;
 ELSE v_count:=0;v_earned:=0;
 END IF;
 INSERT INTO public.steam_completion_progress(user_id,platform_game_id,source_steam_id,membership_revision,
   required_count,earned_count,is_complete,earned_at)
 VALUES(p_user_id,p_app_id,p_steam_id,CASE WHEN c.review_state='verified' THEN c.membership_revision ELSE NULL END,
   v_count,v_earned,v_complete,v_time)
 ON CONFLICT(user_id,platform_game_id) DO UPDATE SET source_steam_id=EXCLUDED.source_steam_id,
   membership_revision=EXCLUDED.membership_revision,required_count=EXCLUDED.required_count,
   earned_count=EXCLUDED.earned_count,is_complete=EXCLUDED.is_complete,earned_at=EXCLUDED.earned_at,checked_at=now();
 RETURN jsonb_build_object('review_state',c.review_state,'membership_revision',c.membership_revision);
END; $$;
CREATE FUNCTION public.mark_steam_completions_synced(p_user_id uuid,p_steam_id text,p_sync_log_id bigint)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM public.assert_steam_completion_sync(p_user_id,p_steam_id,p_sync_log_id);
 INSERT INTO public.steam_completion_sync_state(user_id,source_steam_id) VALUES(p_user_id,p_steam_id)
 ON CONFLICT(user_id) DO UPDATE SET source_steam_id=EXCLUDED.source_steam_id,synced_at=now();
END; $$;
REVOKE ALL ON FUNCTION public.assert_steam_completion_sync(uuid,text,bigint),
 public.review_steam_completion_set(text,text[],text[],jsonb),
 public.record_steam_completion(uuid,text,bigint,text,text[],jsonb),public.mark_steam_completions_synced(uuid,text,bigint)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.review_steam_completion_set(text,text[],text[],jsonb),
 public.record_steam_completion(uuid,text,bigint,text,text[],jsonb),public.mark_steam_completions_synced(uuid,text,bigint) TO service_role;

CREATE FUNCTION public.queue_steam_completion_refresh() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF TG_TABLE_NAME='steam_completion_progress' THEN
   IF TG_OP='INSERT' OR (NEW.source_steam_id,NEW.membership_revision,NEW.is_complete,NEW.earned_at)
      IS DISTINCT FROM (OLD.source_steam_id,OLD.membership_revision,OLD.is_complete,OLD.earned_at) THEN
     INSERT INTO public.leaderboard_refresh_jobs(user_id,kind,source_platform) VALUES(NEW.user_id,'statusxp','steam');
   END IF;
 ELSIF TG_OP='INSERT' OR (NEW.review_state,NEW.membership_revision,NEW.base_status_xp)
   IS DISTINCT FROM (OLD.review_state,OLD.membership_revision,OLD.base_status_xp) THEN
   INSERT INTO public.leaderboard_refresh_jobs(user_id,kind,source_platform)
   SELECT owners.user_id,'statusxp','steam' FROM (
     SELECT user_id FROM public.user_achievement_unlocks WHERE platform_id=4 AND platform_game_id=NEW.platform_game_id
     UNION SELECT user_id FROM public.steam_completion_progress WHERE platform_game_id=NEW.platform_game_id
   ) owners;
 END IF; RETURN NEW;
END; $$;
REVOKE ALL ON FUNCTION public.queue_steam_completion_refresh() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER queue_steam_completion_progress AFTER INSERT OR UPDATE ON public.steam_completion_progress
 FOR EACH ROW EXECUTE FUNCTION public.queue_steam_completion_refresh();
CREATE TRIGGER queue_steam_completion_catalog AFTER INSERT OR UPDATE ON public.steam_completion_catalog
 FOR EACH ROW EXECUTE FUNCTION public.queue_steam_completion_refresh();

CREATE FUNCTION public.get_steam_completion_stats(p_user_id uuid)
RETURNS TABLE(completion_count bigint,pending_review_count bigint,completions_synced boolean)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
SELECT CASE WHEN s.user_id IS NOT NULL THEN (SELECT count(*) FROM public.steam_completion_awards a WHERE a.user_id=p.id) ELSE NULL END,
 (SELECT count(*) FROM public.steam_completion_progress r JOIN public.steam_completion_catalog c USING(platform_game_id)
   WHERE r.user_id=p.id AND r.source_steam_id=p.steam_id::text
   AND (c.review_state<>'verified' OR r.membership_revision IS DISTINCT FROM c.membership_revision)),
 s.user_id IS NOT NULL
FROM public.profiles_private p LEFT JOIN public.steam_completion_sync_state s
 ON s.user_id=p.id AND s.source_steam_id=p.steam_id::text
WHERE p.id=p_user_id AND p.merged_into_user_id IS NULL
 AND (p.show_on_leaderboard OR p.id=auth.uid() OR auth.role()='service_role');
$$;
CREATE VIEW public.steam_completion_leaderboard WITH(security_barrier=true) AS
SELECT x.user_id,x.display_name,x.avatar_url,count(a.user_id)::bigint completion_count,
 x.achievement_count,x.total_games,s.synced_at
FROM public.steam_leaderboard_cache x
JOIN public.profiles_private p ON p.id=x.user_id AND p.merged_into_user_id IS NULL
JOIN public.steam_completion_sync_state s ON s.user_id=x.user_id AND s.source_steam_id=p.steam_id::text
LEFT JOIN public.steam_completion_awards a ON a.user_id=x.user_id
GROUP BY x.user_id,x.display_name,x.avatar_url,x.achievement_count,x.total_games,s.synced_at;
GRANT SELECT ON public.steam_completion_leaderboard TO anon,authenticated,service_role;

CREATE FUNCTION public.get_steam_completion_leaderboard(limit_count integer DEFAULT 100,offset_count integer DEFAULT 0)
RETURNS TABLE(user_id uuid,display_name text,avatar_url text,completion_count bigint,achievement_count bigint,
 total_games bigint,previous_rank integer,rank_change integer,is_new boolean)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
WITH ranked AS (
 SELECT x.*,row_number() OVER(ORDER BY x.completion_count DESC,x.achievement_count DESC,x.user_id) current_rank
 FROM public.steam_completion_leaderboard x
), previous AS (
 SELECT DISTINCT ON(h.user_id) h.user_id,h.rank FROM public.steam_completion_leaderboard_history h
 WHERE h.snapshot_at<now()-interval '1 hour' ORDER BY h.user_id,h.snapshot_at DESC
)
SELECT r.user_id,r.display_name,r.avatar_url,r.completion_count,r.achievement_count,r.total_games,
 h.rank,COALESCE(h.rank-r.current_rank::integer,0),h.rank IS NULL
FROM ranked r LEFT JOIN previous h USING(user_id) ORDER BY r.current_rank
LIMIT greatest(limit_count,0) OFFSET greatest(offset_count,0);
$$;
CREATE FUNCTION public.get_steam_completion_period_leaderboard(p_period_type text DEFAULT 'weekly',limit_count integer DEFAULT 100,offset_count integer DEFAULT 0)
RETURNS TABLE(user_id uuid,display_name text,avatar_url text,period_gain bigint,completion_count bigint,
 achievement_count bigint,total_games bigint,current_rank bigint)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
WITH bounds AS (
 SELECT public.get_leaderboard_period_start(p_period_type,now()) start_at,
 CASE WHEN lower(p_period_type)='monthly' THEN interval '1 month' ELSE interval '7 days' END duration
), gains AS (
 SELECT a.user_id,count(*) gain FROM public.steam_completion_awards a CROSS JOIN bounds b
 WHERE a.earned_at>=b.start_at AND a.earned_at<b.start_at+b.duration GROUP BY a.user_id
), ranked AS (
 SELECT x.*,COALESCE(g.gain,0)::bigint gain,
 row_number() OVER(ORDER BY COALESCE(g.gain,0) DESC,x.completion_count DESC,x.user_id) rank
 FROM public.steam_completion_leaderboard x LEFT JOIN gains g USING(user_id)
)
SELECT r.user_id,r.display_name,r.avatar_url,r.gain,r.completion_count,r.achievement_count,r.total_games,r.rank
FROM ranked r ORDER BY r.rank LIMIT greatest(limit_count,0) OFFSET greatest(offset_count,0);
$$;
GRANT EXECUTE ON FUNCTION public.get_steam_completion_stats(uuid),public.get_steam_completion_leaderboard(integer,integer),
 public.get_steam_completion_period_leaderboard(text,integer,integer) TO anon,authenticated,service_role;

-- Shared scoring and game readers are extended below from inspected live definitions.
CREATE OR REPLACE VIEW public.statusxp_score_events AS
 SELECT ua.user_id,
    ua.platform_id,
    ua.platform_game_id,
    ua.earned_at,
    (a.base_status_xp * COALESCE(a.rarity_multiplier, 1.0)) AS points,
    1 AS achievement_count
   FROM (user_achievement_unlocks ua
     JOIN achievements a USING (platform_id, platform_game_id, platform_achievement_id))
  WHERE (a.include_in_score = true)
UNION ALL
 SELECT m.user_id,
    m.platform_id,
    m.platform_game_id,
    m.earned_at,
    m.base_status_xp AS points,
    0 AS achievement_count
   FROM statusxp_completion_awards m;

CREATE OR REPLACE VIEW statusxp_private.statusxp_refresh_totals AS
 WITH scored_games AS (
         SELECT e.user_id,
            e.platform_id,
            e.platform_game_id,
            (sum(e.points))::integer AS earned_xp
           FROM (statusxp_score_events e
             JOIN games g USING (platform_id, platform_game_id))
          GROUP BY e.user_id, e.platform_id, e.platform_game_id
        ), scores AS (
         SELECT scored_games.user_id,
            sum(scored_games.earned_xp) AS total_statusxp,
            (count(*))::integer AS total_game_entries
           FROM scored_games
          GROUP BY scored_games.user_id
        ), owned AS (
         SELECT user_achievement_unlocks.user_id,
            user_achievement_unlocks.platform_id,
            user_achievement_unlocks.platform_game_id
           FROM user_achievement_unlocks
        UNION
         SELECT statusxp_completion_awards.user_id,
            statusxp_completion_awards.platform_id,
            statusxp_completion_awards.platform_game_id
           FROM statusxp_completion_awards
        ), potential AS (
         SELECT ug.user_id,
            (sum(g.potential))::bigint AS potential_statusxp
           FROM (owned ug
             JOIN statusxp_possible_game_points g USING (platform_id, platform_game_id))
          GROUP BY ug.user_id
        )
 SELECT p.id AS user_id,
    s.total_statusxp,
    COALESCE(t.potential_statusxp, (0)::bigint) AS potential_statusxp,
    s.total_game_entries
   FROM ((scores s
     JOIN profiles_private p ON ((p.id = s.user_id)))
     LEFT JOIN potential t ON ((t.user_id = s.user_id)))
  WHERE ((p.show_on_leaderboard = true) AND (p.merged_into_user_id IS NULL) AND (s.total_statusxp > 0));

CREATE OR REPLACE VIEW public.statusxp_possible_game_points WITH(security_invoker=true) AS
SELECT platform_id,platform_game_id,sum(points) AS potential FROM (
 SELECT platform_id,platform_game_id,base_status_xp points FROM public.achievements WHERE include_in_score=true
 UNION ALL SELECT platform_id,platform_game_id,base_status_xp FROM public.xbox_mythic_catalog
 UNION ALL SELECT platform_id,platform_game_id,base_status_xp FROM public.steam_completion_catalog WHERE review_state='verified'
) catalog GROUP BY platform_id,platform_game_id;

CREATE OR REPLACE FUNCTION public.refresh_statusxp_leaderboard_for_user(p_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.profiles_private WHERE id=p_user_id
   AND show_on_leaderboard=true AND merged_into_user_id IS NULL) THEN
   DELETE FROM public.leaderboard_cache WHERE user_id=p_user_id; RETURN;
 END IF;
 INSERT INTO public.leaderboard_cache(user_id,total_statusxp,potential_statusxp,total_game_entries,last_updated)
 SELECT p_user_id,sum(s.statusxp_effective)::bigint,
   (SELECT COALESCE(sum(g.potential),0)::bigint FROM (
      SELECT platform_id,platform_game_id FROM public.user_achievement_unlocks WHERE user_id=p_user_id
      UNION SELECT platform_id,platform_game_id FROM public.statusxp_completion_awards WHERE user_id=p_user_id
    ) ug JOIN public.statusxp_possible_game_points g USING(platform_id,platform_game_id)),
   count(*)::integer,now()
 FROM public.calculate_statusxp_with_stacks(p_user_id) s HAVING sum(s.statusxp_effective)>0
 ON CONFLICT(user_id) DO UPDATE SET total_statusxp=EXCLUDED.total_statusxp,
   potential_statusxp=EXCLUDED.potential_statusxp,total_game_entries=EXCLUDED.total_game_entries,last_updated=now();
 IF NOT FOUND THEN DELETE FROM public.leaderboard_cache WHERE user_id=p_user_id; END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_dashboard_games(p_user_id uuid)
 RETURNS TABLE(group_id text, name text, cover_url text, proxied_cover_url text, platforms jsonb[], total_statusxp numeric, avg_completion numeric, last_played_at timestamp with time zone, game_title_ids bigint[])
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
WITH selected_games AS MATERIALIZED (
 SELECT up.* FROM public.user_progress up
 JOIN public.games g USING(platform_id,platform_game_id)
 WHERE up.user_id=p_user_id AND (p_user_id=auth.uid() OR auth.role()='service_role')
 ORDER BY COALESCE(up.last_achievement_earned_at,up.last_played_at) DESC NULLS LAST,g.name,up.platform_id,up.platform_game_id
 LIMIT 20
)
SELECT 'group_'||identity.game_title_id::text,g.name,g.cover_url,
 CASE WHEN g.cover_url LIKE '%cloudfront%' OR g.cover_url LIKE '%supabase%' THEN g.cover_url ELSE NULL END,
 ARRAY[jsonb_build_object(
  'code',lower(CASE WHEN p.code IN('PS3','PS4','PS5','PSVITA') THEN 'psn'
   WHEN p.code IN('XBOX360','XBOXONE','XBOXSERIESX','Xbox') THEN 'xbox'
   WHEN p.code='Steam' THEN 'steam' ELSE 'unknown' END),
  'completion',up.completion_percentage,'statusxp',(ea.statusxp+COALESCE(mythic.base_status_xp,0))::integer::numeric,
  'game_title_id',identity.game_title_id,'earned_trophies',up.achievements_earned,
  'total_trophies',CASE WHEN totals.total_achievements>0 THEN totals.total_achievements ELSE up.total_achievements END,
  'bronze_trophies',ea.bronze_trophies,'silver_trophies',ea.silver_trophies,
  'gold_trophies',ea.gold_trophies,'platinum_trophies',ea.platinum_trophies,
  'xbox_achievements_earned',up.achievements_earned,
  'xbox_total_achievements',CASE WHEN totals.total_achievements>0 THEN totals.total_achievements ELSE up.total_achievements END,
  'platform_id',up.platform_id,'platform_game_id',up.platform_game_id,
  'current_score',COALESCE(up.current_score,0),'total_score',totals.total_score,
  'rarest_achievement_rarity',ea.rarest_achievement_rarity,'last_played_at',up.last_played_at,
  'last_trophy_earned_at',ea.last_earned_at
 )]::jsonb[],(ea.statusxp+COALESCE(mythic.base_status_xp,0))::integer::numeric,COALESCE(up.completion_percentage,0),
 COALESCE(ea.last_earned_at,up.last_played_at),ARRAY[identity.game_title_id]
FROM selected_games up
JOIN public.games g ON g.platform_id=up.platform_id AND g.platform_game_id=up.platform_game_id
LEFT JOIN public.platforms p ON p.id=up.platform_id
CROSS JOIN LATERAL (
 SELECT ((('x'||substr(md5(up.platform_id::text||'_'||up.platform_game_id),1,15))::bit(60))::bigint) game_title_id
) identity
CROSS JOIN LATERAL (
 SELECT count(*)::bigint total_achievements,COALESCE(sum(a.score_value),0)::bigint total_score
 FROM public.achievements a
 WHERE a.platform_id=up.platform_id AND a.platform_game_id=up.platform_game_id
) totals
CROSS JOIN LATERAL (
 SELECT count(*) FILTER(WHERE a.metadata->>'psn_trophy_type'='bronze')::bigint bronze_trophies,
  count(*) FILTER(WHERE a.metadata->>'psn_trophy_type'='silver')::bigint silver_trophies,
  count(*) FILTER(WHERE a.metadata->>'psn_trophy_type'='gold')::bigint gold_trophies,
  count(*) FILTER(WHERE a.metadata->>'psn_trophy_type'='platinum')::bigint platinum_trophies,
  COALESCE(sum(CASE WHEN a.include_in_score THEN a.base_status_xp*COALESCE(a.rarity_multiplier,1) ELSE 0 END),0)::numeric statusxp,
  min(a.rarity_global) rarest_achievement_rarity,max(ua.earned_at) last_earned_at
 FROM public.user_achievement_unlocks ua
 JOIN public.achievements a USING(platform_id,platform_game_id,platform_achievement_id)
 WHERE ua.user_id=p_user_id AND ua.platform_id=up.platform_id AND ua.platform_game_id=up.platform_game_id
) ea
LEFT JOIN public.statusxp_completion_awards mythic ON mythic.user_id=p_user_id AND mythic.platform_id=up.platform_id AND mythic.platform_game_id=up.platform_game_id
WHERE up.user_id=p_user_id
ORDER BY COALESCE(ea.last_earned_at,up.last_played_at) DESC NULLS LAST,g.name;
$function$;

CREATE OR REPLACE FUNCTION public.get_user_grouped_games(p_user_id uuid)
 RETURNS TABLE(group_id text, name text, cover_url text, proxied_cover_url text, platforms jsonb[], total_statusxp numeric, avg_completion numeric, last_played_at timestamp with time zone, game_title_ids bigint[])
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
 SET statement_timeout TO '15s'
AS $function$
DECLARE library_sql text;
BEGIN
 -- Covering indexes keep both large and small collections on indexed facts.
 library_sql := $library$
WITH library_definitions AS NOT MATERIALIZED (
 SELECT a.platform_id,a.platform_game_id,a.platform_achievement_id,a.score_value,
  a.base_status_xp,a.rarity_multiplier,a.rarity_global,a.include_in_score
 FROM public.achievements a
), user_unlocks AS MATERIALIZED (SELECT user_id,platform_id,platform_game_id,platform_achievement_id,earned_at FROM public.user_achievement_unlocks WHERE user_id=$1), user_games_base AS MATERIALIZED (
  SELECT
    up.platform_id,
    up.platform_game_id,
    ((('x' || substr(md5(up.platform_id::text || '_' || up.platform_game_id), 1, 15))::bit(60))::bigint) AS game_title_id,
    g.name AS game_title,
    g.cover_url,
    up.achievements_earned::bigint AS earned_trophies,
    up.total_achievements::bigint AS total_trophies,
    up.completion_percentage AS completion_percent,
    up.last_played_at,
    up.current_score,
    p.code AS platform_code
  FROM public.user_progress up
  JOIN public.games g
    ON g.platform_id = up.platform_id
   AND g.platform_game_id = up.platform_game_id
  LEFT JOIN public.platforms p ON p.id = up.platform_id
  WHERE up.user_id = $1
),
trophy_types AS MATERIALIZED (
SELECT 'bronze'::text AS trophy_type,platform_id,platform_game_id,platform_achievement_id FROM public.achievements WHERE metadata->>'psn_trophy_type'='bronze'
UNION ALL
SELECT 'silver'::text AS trophy_type,platform_id,platform_game_id,platform_achievement_id FROM public.achievements WHERE metadata->>'psn_trophy_type'='silver'
UNION ALL
SELECT 'gold'::text AS trophy_type,platform_id,platform_game_id,platform_achievement_id FROM public.achievements WHERE metadata->>'psn_trophy_type'='gold'
UNION ALL
SELECT 'platinum'::text AS trophy_type,platform_id,platform_game_id,platform_achievement_id FROM public.achievements WHERE metadata->>'psn_trophy_type'='platinum'
), trophy_counts AS (
 SELECT ua.platform_id,ua.platform_game_id,
 count(*) FILTER(WHERE t.trophy_type='bronze')::bigint AS bronze_trophies,
 count(*) FILTER(WHERE t.trophy_type='silver')::bigint AS silver_trophies,
 count(*) FILTER(WHERE t.trophy_type='gold')::bigint AS gold_trophies,
 count(*) FILTER(WHERE t.trophy_type='platinum')::bigint AS platinum_trophies
 FROM user_unlocks ua JOIN trophy_types t USING(platform_id,platform_game_id,platform_achievement_id)
 GROUP BY ua.platform_id,ua.platform_game_id
),
game_stats AS MATERIALIZED (
 SELECT a.platform_id,a.platform_game_id,
  count(*)::bigint AS total_achievements,
  coalesce(sum(a.score_value),0)::bigint AS total_score,
  coalesce(sum(CASE WHEN ua.platform_achievement_id IS NOT NULL AND a.include_in_score THEN a.base_status_xp*coalesce(a.rarity_multiplier,1.0) ELSE 0 END),0)::numeric AS statusxp,
  min(a.rarity_global) FILTER(WHERE ua.platform_achievement_id IS NOT NULL) AS rarest_achievement_rarity,
  max(ua.earned_at) AS last_earned_at
 FROM user_games_base ugb
 JOIN library_definitions a ON a.platform_id=ugb.platform_id AND a.platform_game_id=ugb.platform_game_id
 LEFT JOIN user_unlocks ua ON ua.platform_id=a.platform_id AND ua.platform_game_id=a.platform_game_id AND ua.platform_achievement_id=a.platform_achievement_id
 GROUP BY a.platform_id,a.platform_game_id
)
SELECT
  'group_' || ugb.game_title_id::text,
  ugb.game_title,
  ugb.cover_url,
  CASE
    WHEN ugb.cover_url LIKE '%cloudfront%' OR ugb.cover_url LIKE '%supabase%'
      THEN ugb.cover_url
    ELSE NULL
  END,
  ARRAY[
    jsonb_build_object(
      'code', LOWER(CASE
        WHEN ugb.platform_code IN ('PS3', 'PS4', 'PS5', 'PSVITA') THEN 'psn'
        WHEN ugb.platform_code IN ('XBOX360', 'XBOXONE', 'XBOXSERIESX', 'Xbox') THEN 'xbox'
        WHEN ugb.platform_code = 'Steam' THEN 'steam'
        ELSE 'unknown'
      END),
      'completion', ugb.completion_percent,
      'statusxp', (COALESCE(ea.statusxp, 0)+COALESCE(mythic.base_status_xp,0))::integer::numeric,
      'game_title_id', ugb.game_title_id,
      'earned_trophies', ugb.earned_trophies,
      'total_trophies', COALESCE(ea.total_achievements, ugb.total_trophies),
      'bronze_trophies', COALESCE(tc.bronze_trophies, 0),
      'silver_trophies', COALESCE(tc.silver_trophies, 0),
      'gold_trophies', COALESCE(tc.gold_trophies, 0),
      'platinum_trophies', COALESCE(tc.platinum_trophies, 0),
      'xbox_achievements_earned', ugb.earned_trophies,
      'xbox_total_achievements', COALESCE(ea.total_achievements, ugb.total_trophies),
      'platform_id', ugb.platform_id,
      'platform_game_id', ugb.platform_game_id,
      'current_score', COALESCE(ugb.current_score, 0),
      'total_score', COALESCE(ea.total_score, 0),
      'rarest_achievement_rarity', ea.rarest_achievement_rarity,
      'last_played_at', ugb.last_played_at,
      'last_trophy_earned_at', ea.last_earned_at
    )
  ]::jsonb[],
  (COALESCE(ea.statusxp, 0)+COALESCE(mythic.base_status_xp,0))::integer::numeric,
  COALESCE(ugb.completion_percent, 0),
  COALESCE(ea.last_earned_at, ugb.last_played_at),
  ARRAY[ugb.game_title_id]
FROM user_games_base ugb
LEFT JOIN trophy_counts tc ON tc.platform_id=ugb.platform_id AND tc.platform_game_id=ugb.platform_game_id
LEFT JOIN game_stats ea ON ea.platform_id=ugb.platform_id AND ea.platform_game_id=ugb.platform_game_id
LEFT JOIN public.statusxp_completion_awards mythic ON mythic.user_id=$1 AND mythic.platform_id=ugb.platform_id AND mythic.platform_game_id=ugb.platform_game_id
ORDER BY COALESCE(ea.last_earned_at, ugb.last_played_at) DESC NULLS LAST,
         ugb.game_title;
$library$;
 RETURN QUERY EXECUTE library_sql USING p_user_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.snapshot_steam_leaderboard()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  INSERT INTO steam_leaderboard_history (user_id, snapshot_at, rank, achievement_count, total_games)
  SELECT
    user_id,
    now(),
    ROW_NUMBER() OVER (ORDER BY achievement_count DESC, total_games DESC) as rank,
    achievement_count,
    total_games
  FROM steam_leaderboard_cache
  ORDER BY rank;

  RAISE NOTICE 'Steam leaderboard snapshot created at %', now();
 INSERT INTO public.steam_completion_leaderboard_history(user_id,snapshot_at,rank,completion_count)
 SELECT x.user_id,now(),row_number() OVER(ORDER BY x.completion_count DESC,x.achievement_count DESC,x.user_id)::integer,x.completion_count
 FROM public.steam_completion_leaderboard x ON CONFLICT(user_id,snapshot_at) DO UPDATE
 SET rank=EXCLUDED.rank,completion_count=EXCLUDED.completion_count;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_user_seasonal_game_breakdown(p_target_user_id uuid, p_board_type text DEFAULT 'statusxp'::text, p_period_type text DEFAULT 'weekly'::text, limit_count integer DEFAULT 200, offset_count integer DEFAULT 0)
 RETURNS TABLE(platform_id integer, platform_game_id text, game_name text, cover_url text, period_gain bigint, earned_count integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
WITH input AS (
  SELECT
    CASE
      WHEN LOWER(COALESCE(p_board_type, 'statusxp')) IN ('statusxp', 'psn', 'xbox', 'steam')
        THEN LOWER(COALESCE(p_board_type, 'statusxp'))
      ELSE 'statusxp'
    END AS board_type,
    CASE
      WHEN LOWER(COALESCE(p_period_type, 'weekly')) = 'monthly' THEN 'monthly'
      ELSE 'weekly'
    END AS period_type
),
period_window AS (
  SELECT
    i.period_type,
    public.get_leaderboard_period_start(i.period_type, now()) AS period_start,
    CASE
      WHEN i.period_type = 'monthly'
        THEN public.get_leaderboard_period_start(i.period_type, now()) + INTERVAL '1 month'
      ELSE public.get_leaderboard_period_start(i.period_type, now()) + INTERVAL '7 days'
    END AS period_end
  FROM input i
),
target_user AS (
  SELECT p.id AS user_id
  FROM public.profiles p
  WHERE p.id = p_target_user_id
    AND (p.show_on_leaderboard = true OR p.id = auth.uid())
),
breakdown_rows AS (
  SELECT e.platform_id,e.platform_game_id,e.points::numeric contribution
  FROM public.statusxp_score_events e JOIN target_user tu ON tu.user_id=e.user_id
  CROSS JOIN input i CROSS JOIN period_window w
  WHERE i.board_type='statusxp' AND e.earned_at>=w.period_start AND e.earned_at<w.period_end
  UNION ALL
  SELECT
    ua.platform_id,
    ua.platform_game_id,
    1::numeric AS contribution
  FROM public.user_achievements ua
  JOIN public.achievements a
    ON a.platform_id = ua.platform_id
   AND a.platform_game_id = ua.platform_game_id
   AND a.platform_achievement_id = ua.platform_achievement_id
  JOIN target_user tu ON tu.user_id = ua.user_id
  CROSS JOIN input i
  CROSS JOIN period_window w
  WHERE i.board_type = 'psn'
    AND ua.platform_id IN (1, 2, 5, 9)
    AND ua.earned_at >= w.period_start
    AND ua.earned_at < w.period_end
    AND a.is_platinum = true
  UNION ALL
  SELECT m.platform_id,m.platform_game_id,1::numeric contribution
  FROM public.xbox_mythic_awards m JOIN target_user tu ON tu.user_id=m.user_id
  CROSS JOIN input i CROSS JOIN period_window w
  WHERE i.board_type='xbox' AND m.earned_at>=w.period_start AND m.earned_at<w.period_end
  UNION ALL
  SELECT a.platform_id,a.platform_game_id,1::numeric contribution
  FROM public.steam_completion_awards a JOIN target_user tu ON tu.user_id=a.user_id
  CROSS JOIN input i CROSS JOIN period_window w
  WHERE i.board_type='steam' AND a.earned_at>=w.period_start AND a.earned_at<w.period_end

),
grouped AS (
  SELECT
    br.platform_id,
    br.platform_game_id,
    SUM(br.contribution)::bigint AS period_gain,
    COUNT(*)::integer AS earned_count
  FROM breakdown_rows br
  GROUP BY br.platform_id, br.platform_game_id
)
SELECT
  g2.platform_id::integer,
  g2.platform_game_id,
  COALESCE(g.name, g2.platform_game_id)::text AS game_name,
  g.cover_url,
  g2.period_gain,
  g2.earned_count
FROM grouped g2
LEFT JOIN public.games g
  ON g.platform_id = g2.platform_id
 AND g.platform_game_id = g2.platform_game_id
ORDER BY
  g2.period_gain DESC,
  g2.earned_count DESC,
  COALESCE(g.name, g2.platform_game_id) ASC
LIMIT GREATEST(limit_count, 0)
OFFSET GREATEST(offset_count, 0);
$function$;

CREATE OR REPLACE FUNCTION public.get_leaderboard_hall_of_fame(p_period_type text DEFAULT 'weekly'::text, p_leaderboard_type text DEFAULT NULL::text, limit_count integer DEFAULT 100)
 RETURNS TABLE(leaderboard_type text, period_type text, period_start timestamp with time zone, period_end timestamp with time zone, winner_user_id uuid, winner_display_name text, winner_avatar_url text, winner_gain bigint, winner_current_score bigint)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
 SET statement_timeout TO '25s'
AS $function$
WITH settings AS (
  SELECT CASE
    WHEN LOWER(COALESCE(p_period_type, 'weekly')) = 'monthly' THEN 'monthly'
    ELSE 'weekly'
  END AS period_type
),
request_limits AS (
  SELECT
    LEAST(GREATEST(limit_count, 0), 120)::int AS effective_limit,
    CASE
      WHEN LOWER(COALESCE(p_leaderboard_type, '')) IN ('statusxp', 'psn', 'xbox', 'steam')
        THEN 1
      ELSE 4
    END::int AS board_count
),
current_bounds AS (
  SELECT
    s.period_type,
    public.get_leaderboard_period_start(s.period_type, now()) AS current_period_start,
    CASE
      WHEN s.period_type = 'monthly'
        THEN (date_trunc('month', timezone('UTC', now())) AT TIME ZONE 'UTC')
      ELSE (
        (
          date_trunc('day', timezone('America/New_York', now()))
          - (((extract(dow from timezone('America/New_York', now()))::int - 2 + 7) % 7) * interval '1 day')
        ) AT TIME ZONE 'America/New_York'
      )
    END AS default_start
  FROM settings s
),
reset_floor AS (
  SELECT MAX(spo.start_at) AS weekly_floor
  FROM public.seasonal_period_overrides spo
  WHERE spo.period_type = 'weekly'
),
periods_needed AS (
  SELECT
    CASE
      WHEN cb.period_type = 'monthly' THEN
        LEAST(
          GREATEST(((rl.effective_limit + rl.board_count - 1) / rl.board_count) + 2, 6),
          24
        )
      ELSE
        LEAST(
          GREATEST(((rl.effective_limit + rl.board_count - 1) / rl.board_count) + 2, 8),
          52
        )
    END AS n,
    rl.effective_limit
  FROM current_bounds cb
  CROSS JOIN request_limits rl
),
base_periods AS (
  SELECT
    cb.period_type,
    gs AS period_start,
    CASE
      WHEN cb.period_type = 'monthly' THEN gs + INTERVAL '1 month'
      ELSE gs + INTERVAL '7 days'
    END AS period_end
  FROM current_bounds cb
  CROSS JOIN periods_needed pn
  LEFT JOIN reset_floor rf ON TRUE
  CROSS JOIN LATERAL (
    SELECT generate_series(
      CASE
        WHEN cb.period_type = 'monthly'
          THEN (cb.default_start - (pn.n * INTERVAL '1 month'))
        ELSE (cb.default_start - (pn.n * INTERVAL '7 days'))
      END,
      CASE
        WHEN cb.period_type = 'monthly'
          THEN (cb.default_start - INTERVAL '1 month')
        ELSE (cb.default_start - INTERVAL '7 days')
      END,
      CASE
        WHEN cb.period_type = 'monthly' THEN INTERVAL '1 month'
        ELSE INTERVAL '7 days'
      END
    ) AS gs
  ) gen
  WHERE gs < cb.current_period_start
    AND (
      cb.period_type <> 'weekly'
      OR gs >= COALESCE(rf.weekly_floor, '-infinity'::timestamptz)
    )
),
override_periods AS (
  SELECT
    cb.period_type,
    spo.start_at AS period_start,
    COALESCE(
      spo.end_at,
      CASE
        WHEN cb.period_type = 'monthly' THEN spo.start_at + INTERVAL '1 month'
        ELSE spo.start_at + INTERVAL '7 days'
      END
    ) AS period_end
  FROM current_bounds cb
  JOIN public.seasonal_period_overrides spo
    ON spo.period_type = cb.period_type
  LEFT JOIN reset_floor rf ON TRUE
  WHERE spo.start_at < cb.current_period_start
    AND (
      cb.period_type <> 'weekly'
      OR spo.start_at >= COALESCE(rf.weekly_floor, '-infinity'::timestamptz)
    )
),
closed_periods AS (
  SELECT * FROM base_periods
  UNION
  SELECT * FROM override_periods
),
trimmed_periods AS (
  SELECT *
  FROM closed_periods
  ORDER BY period_start DESC
  LIMIT (SELECT n FROM periods_needed)
),
time_bounds AS (
  SELECT
    MIN(tp.period_start) AS min_start,
    MAX(tp.period_end) AS max_end
  FROM trimmed_periods tp
),
statusxp_gains AS (
 SELECT CASE WHEN cb.period_type='monthly'
   THEN date_trunc('month',timezone('UTC',e.earned_at)) AT TIME ZONE 'UTC'
   ELSE public.get_leaderboard_period_start('weekly',e.earned_at) END period_start,
 e.user_id,sum(e.points)::bigint gain
 FROM public.statusxp_score_events e CROSS JOIN current_bounds cb CROSS JOIN time_bounds tb
 WHERE e.earned_at>=tb.min_start AND e.earned_at<tb.max_end GROUP BY 1,2
),
psn_gains AS (
  SELECT
    CASE
      WHEN cb.period_type = 'monthly'
        THEN (date_trunc('month', timezone('UTC', ua.earned_at)) AT TIME ZONE 'UTC')
      ELSE public.get_leaderboard_period_start('weekly', ua.earned_at)
    END AS period_start,
    ua.user_id,
    COUNT(*) FILTER (WHERE a.is_platinum = true)::bigint AS gain
  FROM public.user_achievements ua
  JOIN public.achievements a ON
    a.platform_id = ua.platform_id
    AND a.platform_game_id = ua.platform_game_id
    AND a.platform_achievement_id = ua.platform_achievement_id
  CROSS JOIN current_bounds cb
  CROSS JOIN time_bounds tb
  WHERE ua.platform_id IN (1, 2, 5, 9)
    AND ua.earned_at IS NOT NULL
    AND ua.earned_at >= tb.min_start
    AND ua.earned_at < tb.max_end
  GROUP BY 1, 2
),
xbox_gains AS (
 SELECT CASE WHEN cb.period_type='monthly'
   THEN date_trunc('month',timezone('UTC',m.earned_at)) AT TIME ZONE 'UTC'
   ELSE public.get_leaderboard_period_start('weekly',m.earned_at) END period_start,
 m.user_id,count(*)::bigint gain
 FROM public.xbox_mythic_awards m CROSS JOIN current_bounds cb CROSS JOIN time_bounds tb
 WHERE m.earned_at>=tb.min_start AND m.earned_at<tb.max_end GROUP BY 1,2
),
steam_gains AS (
 SELECT CASE WHEN cb.period_type='monthly'
 THEN date_trunc('month',timezone('UTC',a.earned_at)) AT TIME ZONE 'UTC'
 ELSE public.get_leaderboard_period_start('weekly',a.earned_at) END period_start,
 a.user_id,count(*)::bigint gain
 FROM public.steam_completion_awards a CROSS JOIN current_bounds cb CROSS JOIN time_bounds tb
 WHERE a.earned_at>=tb.min_start AND a.earned_at<tb.max_end GROUP BY 1,2
),
statusxp_candidates AS (
  SELECT
    'statusxp'::text AS leaderboard_type,
    tp.period_type,
    tp.period_start,
    tp.period_end,
    g.user_id,
    COALESCE(
      CASE p.preferred_display_platform
        WHEN 'psn' THEN p.psn_online_id
        WHEN 'xbox' THEN p.xbox_gamertag
        WHEN 'steam' THEN p.steam_display_name
      END,
      p.psn_online_id,
      p.xbox_gamertag,
      p.steam_display_name,
      p.display_name,
      p.username,
      'Player'::text
    ) AS display_name,
    COALESCE(
      CASE p.preferred_display_platform
        WHEN 'psn' THEN p.psn_avatar_url
        WHEN 'xbox' THEN p.xbox_avatar_url
        WHEN 'steam' THEN p.steam_avatar_url
      END,
      p.avatar_url
    ) AS avatar_url,
    COALESCE(g.gain, 0)::bigint AS gain
  FROM trimmed_periods tp
  JOIN statusxp_gains g ON g.period_start = tp.period_start
  JOIN public.profiles p ON p.id = g.user_id
  WHERE p.show_on_leaderboard = true
),
psn_candidates AS (
  SELECT
    'psn'::text AS leaderboard_type,
    tp.period_type,
    tp.period_start,
    tp.period_end,
    g.user_id,
    COALESCE(p.psn_online_id, p.display_name, p.username, 'Player'::text) AS display_name,
    COALESCE(p.psn_avatar_url, p.avatar_url) AS avatar_url,
    COALESCE(g.gain, 0)::bigint AS gain
  FROM trimmed_periods tp
  JOIN psn_gains g ON g.period_start = tp.period_start
  JOIN public.profiles p ON p.id = g.user_id
  WHERE p.show_on_leaderboard = true
),
xbox_candidates AS (
  SELECT
    'xbox'::text AS leaderboard_type,
    tp.period_type,
    tp.period_start,
    tp.period_end,
    g.user_id,
    COALESCE(p.xbox_gamertag, p.display_name, p.username, 'Player'::text) AS display_name,
    COALESCE(p.xbox_avatar_url, p.avatar_url) AS avatar_url,
    COALESCE(g.gain, 0)::bigint AS gain
  FROM trimmed_periods tp
  JOIN xbox_gains g ON g.period_start = tp.period_start
  JOIN public.profiles p ON p.id = g.user_id
  WHERE p.show_on_leaderboard = true
),
steam_candidates AS (
  SELECT
    'steam'::text AS leaderboard_type,
    tp.period_type,
    tp.period_start,
    tp.period_end,
    g.user_id,
    COALESCE(p.steam_display_name, p.display_name, p.username, 'Player'::text) AS display_name,
    COALESCE(p.steam_avatar_url, p.avatar_url) AS avatar_url,
    COALESCE(g.gain, 0)::bigint AS gain
  FROM trimmed_periods tp
  JOIN steam_gains g ON g.period_start = tp.period_start
  JOIN public.profiles p ON p.id = g.user_id
  WHERE p.show_on_leaderboard = true
),
all_candidates AS (
  SELECT * FROM statusxp_candidates
  UNION ALL
  SELECT * FROM psn_candidates
  UNION ALL
  SELECT * FROM xbox_candidates
  UNION ALL
  SELECT * FROM steam_candidates
),
filtered AS (
  SELECT ac.*
  FROM all_candidates ac
  WHERE (
    p_leaderboard_type IS NULL
    OR p_leaderboard_type = ''
    OR ac.leaderboard_type = LOWER(p_leaderboard_type)
  )
),
ranked AS (
  SELECT
    f.*,
    ROW_NUMBER() OVER (
      PARTITION BY f.leaderboard_type, f.period_start
      ORDER BY f.gain DESC, f.user_id ASC
    ) AS winner_rank
  FROM filtered f
),
winners AS (
  SELECT
    r.leaderboard_type,
    r.period_type,
    r.period_start,
    r.period_end,
    r.user_id AS winner_user_id,
    r.display_name AS winner_display_name,
    r.avatar_url AS winner_avatar_url,
    r.gain AS winner_gain
  FROM ranked r
  WHERE r.winner_rank = 1
),
enriched AS (
  SELECT
    w.*,
    COALESCE(
      CASE w.leaderboard_type
        WHEN 'statusxp' THEN (
          SELECT lh.total_statusxp::bigint
          FROM public.leaderboard_history lh
          WHERE lh.user_id = w.winner_user_id
            AND lh.snapshot_at < w.period_end
          ORDER BY lh.snapshot_at DESC
          LIMIT 1
        )
        WHEN 'psn' THEN (
          SELECT ph.platinum_count::bigint
          FROM public.psn_leaderboard_history ph
          WHERE ph.user_id = w.winner_user_id
            AND ph.snapshot_at < w.period_end
          ORDER BY ph.snapshot_at DESC
          LIMIT 1
        )
        WHEN 'xbox' THEN (SELECT count(*)::bigint FROM public.xbox_mythic_awards m WHERE m.user_id=w.winner_user_id AND m.earned_at<w.period_end)
        WHEN 'steam' THEN (SELECT count(*)::bigint FROM public.steam_completion_awards a WHERE a.user_id=w.winner_user_id AND a.earned_at<w.period_end)
        ELSE NULL
      END,
      CASE w.leaderboard_type
        WHEN 'statusxp' THEN (
          SELECT lc.total_statusxp::bigint
          FROM public.leaderboard_cache lc
          WHERE lc.user_id = w.winner_user_id
        )
        WHEN 'psn' THEN (
          SELECT plc.platinum_count::bigint
          FROM public.psn_leaderboard_cache plc
          WHERE plc.user_id = w.winner_user_id
        )
        WHEN 'xbox' THEN (SELECT count(*)::bigint FROM public.xbox_mythic_awards m WHERE m.user_id=w.winner_user_id)
        WHEN 'steam' THEN (SELECT count(*)::bigint FROM public.steam_completion_awards a WHERE a.user_id=w.winner_user_id)
        ELSE 0::bigint
      END,
      0::bigint
    ) AS winner_current_score
  FROM winners w
)
SELECT
  e.leaderboard_type,
  e.period_type,
  e.period_start,
  e.period_end,
  e.winner_user_id,
  e.winner_display_name,
  e.winner_avatar_url,
  e.winner_gain,
  e.winner_current_score
FROM enriched e
ORDER BY e.period_end DESC, e.leaderboard_type ASC
LIMIT (SELECT effective_limit FROM periods_needed);
$function$;
CREATE FUNCTION public.queue_steam_completion_account_refresh() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NEW.steam_id IS DISTINCT FROM OLD.steam_id
 AND EXISTS(SELECT 1 FROM public.steam_completion_progress WHERE user_id=NEW.id) THEN
 INSERT INTO public.leaderboard_refresh_jobs(user_id,kind,source_platform) VALUES(NEW.id,'statusxp','steam');
 END IF; RETURN NEW;
END; $$;
REVOKE ALL ON FUNCTION public.queue_steam_completion_account_refresh() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER queue_steam_completion_account_refresh AFTER UPDATE OF steam_id ON public.profiles_private
FOR EACH ROW EXECUTE FUNCTION public.queue_steam_completion_account_refresh();
COMMIT;
