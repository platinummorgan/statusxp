BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='120s';

ALTER TABLE public.steam_completion_catalog
 ADD COLUMN completion_policy text CHECK(completion_policy IN('official_base_game','all_achievements')),
 ADD COLUMN policy_version integer NOT NULL DEFAULT 0,
 ADD COLUMN policy_checked_at timestamptz,
 ADD COLUMN policy_next_check_at timestamptz NOT NULL DEFAULT now();
CREATE INDEX steam_completion_policy_due_idx ON public.steam_completion_catalog(policy_next_check_at);
-- Keep dependent views and their contracts; only Steam changes to 1x.
ALTER TABLE public.steam_completion_catalog ALTER COLUMN base_status_xp SET EXPRESSION AS
 (CASE WHEN estimated_rarity IS NULL THEN 0.5
  ELSE round(0.5+11.5*power(1-estimated_rarity/100.0,3),2) END);

-- Preserve the previous manual classifications before replacing their scope.
INSERT INTO public.steam_completion_schema_snapshots(platform_game_id,signature,source,snapshot)
 SELECT platform_game_id,md5(to_jsonb(c)::text),'before_native_steam_policy',to_jsonb(c)
 FROM public.steam_completion_catalog c ON CONFLICT DO NOTHING;
ALTER TABLE public.steam_completion_catalog DISABLE TRIGGER queue_steam_original_membership_review;
-- Queue affected owners once after the bulk transition, rather than once per game.
ALTER TABLE public.steam_completion_catalog DISABLE TRIGGER queue_steam_completion_catalog;

CREATE FUNCTION public.apply_steam_completion_policy(p_app_id text,p_observed_ids text[],p_required_ids text[],
 p_policy text,p_evidence jsonb,p_expected_observed_ids text[],p_retry boolean DEFAULT false)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE c public.steam_completion_catalog%ROWTYPE; v_observed text[];v_required text[];
 v_created boolean:=false;v_rarity numeric;v_revision text;
BEGIN
 SELECT array_agg(DISTINCT id ORDER BY id) INTO v_observed FROM unnest(p_observed_ids) id;
 SELECT COALESCE(array_agg(DISTINCT id ORDER BY id),'{}') INTO v_required FROM unnest(p_required_ids) id;
 IF COALESCE(cardinality(v_observed),0)=0 OR cardinality(v_observed)<>cardinality(p_observed_ids)
  OR cardinality(v_required)<>cardinality(p_required_ids)
  OR EXISTS(SELECT 1 FROM unnest(v_observed) id WHERE id IS NULL OR btrim(id)='')
  OR NOT v_required<@v_observed OR p_policy NOT IN('official_base_game','all_achievements')
  OR p_policy IS NULL OR jsonb_typeof(p_evidence) IS DISTINCT FROM 'object'
  OR p_evidence->>'scope' IS DISTINCT FROM p_policy
  OR p_evidence->>'review_method' IS DISTINCT FROM 'automatic_native_steam_sets'
  OR EXISTS(SELECT 1 FROM unnest(v_observed) id WHERE NOT EXISTS(
    SELECT 1 FROM public.achievements a WHERE a.platform_id=4 AND a.platform_game_id=p_app_id
    AND a.platform_achievement_id=id)) THEN
   RAISE EXCEPTION 'Invalid native Steam membership policy';
 END IF;
 INSERT INTO public.steam_completion_catalog(platform_game_id,observed_ids)
 VALUES(p_app_id,v_observed) ON CONFLICT DO NOTHING RETURNING true INTO v_created;
 SELECT * INTO c FROM public.steam_completion_catalog WHERE platform_game_id=p_app_id FOR UPDATE;
 -- Refreshes based on an older schema cannot overwrite a newer normal sync.
 IF NOT COALESCE(v_created,false) AND c.observed_ids IS DISTINCT FROM p_expected_observed_ids THEN RETURN false; END IF;
 v_revision:=md5(to_jsonb(v_required)::text);
 SELECT CASE WHEN count(*)=cardinality(v_required) AND count(rarity_global)=cardinality(v_required)
  AND cardinality(v_required)>0 THEN min(rarity_global) ELSE NULL END INTO v_rarity
 FROM public.achievements WHERE platform_id=4 AND platform_game_id=p_app_id
  AND platform_achievement_id=ANY(v_required);
 INSERT INTO public.steam_completion_schema_snapshots(platform_game_id,signature,source,snapshot)
 VALUES(p_app_id,md5(jsonb_build_object('observed',v_observed,'required',v_required,'evidence',p_evidence)::text),
  'automatic_native_steam_sets',jsonb_build_object('observed_ids',v_observed,'required_ids',v_required,'evidence',p_evidence))
 ON CONFLICT(platform_game_id,signature,source) DO UPDATE SET last_seen_at=now();
 UPDATE public.steam_completion_catalog SET observed_ids=v_observed,required_ids=v_required,
  excluded_ids=ARRAY(SELECT id FROM unnest(v_observed) id WHERE NOT id=ANY(v_required) ORDER BY id),
  completion_policy=p_policy,policy_version=1,policy_checked_at=now(),
  policy_next_check_at=now()+CASE WHEN p_retry THEN interval '30 minutes' ELSE interval '7 days' END,
  review_state=CASE WHEN cardinality(v_required)>0 THEN 'verified' ELSE 'needs_review' END,
  membership_revision=v_revision,evidence=p_evidence,reviewed_at=now(),estimated_rarity=v_rarity,
  rarity_source='estimated_minimum_'||p_policy WHERE platform_game_id=p_app_id;
 RETURN true;
END $$;
REVOKE ALL ON FUNCTION public.apply_steam_completion_policy(text,text[],text[],text,jsonb,text[],boolean)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.apply_steam_completion_policy(text,text[],text[],text,jsonb,text[],boolean) TO service_role;

-- The old console/day-one worker and review CLI must not replace native scope.
CREATE OR REPLACE FUNCTION public.claim_steam_completion_review_job()
RETURNS SETOF public.steam_completion_review_jobs LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 SELECT * FROM public.steam_completion_review_jobs WHERE false;
$$;
CREATE OR REPLACE FUNCTION public.review_steam_completion_set(p_app_id text,p_required_ids text[],p_excluded_ids text[],p_evidence jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN RAISE EXCEPTION 'Manual day-one membership retired; use native Steam set policy'; END $$;

-- Seed the full-set fallback for every tracked catalog with stored definitions.
-- This creates requirements only, never player unlocks or earned completions.
INSERT INTO public.steam_completion_catalog(platform_game_id,observed_ids)
 SELECT a.platform_game_id,array_agg(a.platform_achievement_id ORDER BY a.platform_achievement_id)
 FROM public.achievements a WHERE a.platform_id=4 AND EXISTS(
  SELECT 1 FROM public.user_progress u WHERE u.platform_id=4 AND u.platform_game_id=a.platform_game_id)
 GROUP BY a.platform_game_id ON CONFLICT DO NOTHING;
DO $$ DECLARE c public.steam_completion_catalog%ROWTYPE; BEGIN
 FOR c IN SELECT * FROM public.steam_completion_catalog WHERE cardinality(observed_ids)>0 LOOP
  PERFORM public.apply_steam_completion_policy(c.platform_game_id,c.observed_ids,c.observed_ids,'all_achievements',
   jsonb_build_object('scope','all_achievements','review_method','automatic_native_steam_sets','policy_version',1,
    'fallback_reason','awaiting_native_group_refresh','sources',jsonb_build_array(
     'https://steamcommunity.com/achievements/'||c.platform_game_id||'/?l=english')),c.observed_ids,true);
 END LOOP;
 UPDATE public.steam_completion_catalog SET policy_next_check_at=now();
END $$;

ALTER TABLE public.steam_completion_catalog ENABLE TRIGGER queue_steam_completion_catalog;
INSERT INTO public.leaderboard_refresh_jobs(user_id,kind,source_platform)
 SELECT DISTINCT user_id,'statusxp','steam' FROM public.user_progress WHERE platform_id=4;

CREATE OR REPLACE FUNCTION public.record_steam_completion(p_user_id uuid,p_steam_id text,p_sync_log_id bigint,
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
   OR jsonb_array_length(p_player_state)<>cardinality(v_schema)
   OR (SELECT count(DISTINCT s->>'apiname') FROM jsonb_array_elements(p_player_state) s)<>jsonb_array_length(p_player_state)
   THEN RAISE EXCEPTION 'Incomplete Steam schema or player response'; END IF;
 INSERT INTO public.steam_completion_catalog(platform_game_id,observed_ids) VALUES(p_app_id,v_schema)
   ON CONFLICT DO NOTHING;
 SELECT * INTO c FROM public.steam_completion_catalog WHERE platform_game_id=p_app_id FOR UPDATE;
 IF c.policy_version<>1 OR c.observed_ids IS DISTINCT FROM v_schema THEN
   PERFORM public.apply_steam_completion_policy(p_app_id,v_schema,v_schema,'all_achievements',
    jsonb_build_object('scope','all_achievements','review_method','automatic_native_steam_sets','policy_version',1,
     'fallback_reason','native_schema_changed','sources',jsonb_build_array(
      'https://steamcommunity.com/achievements/'||p_app_id||'/?l=english')),c.observed_ids,true);
   SELECT * INTO c FROM public.steam_completion_catalog WHERE platform_game_id=p_app_id;
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
 RETURN jsonb_build_object('review_state',c.review_state,'membership_revision',c.membership_revision,'completion_policy',c.completion_policy);
END; $$;

CREATE OR REPLACE FUNCTION public.get_steam_completion_stats(p_user_id uuid)
RETURNS TABLE(completion_count bigint,pending_review_count bigint,completions_synced boolean)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
SELECT CASE WHEN s.user_id IS NOT NULL THEN (SELECT count(*) FROM public.steam_completion_awards a WHERE a.user_id=p.id) ELSE NULL END,
 (SELECT count(*) FROM public.steam_completion_progress r JOIN public.steam_completion_catalog c USING(platform_game_id)
  WHERE r.user_id=p.id AND r.source_steam_id=p.steam_id::text
  AND (c.policy_version<>1 OR cardinality(c.required_ids)>0)
  AND (c.review_state<>'verified' OR r.membership_revision IS DISTINCT FROM c.membership_revision)),
 s.user_id IS NOT NULL
FROM public.profiles_private p LEFT JOIN public.steam_completion_sync_state s
 ON s.user_id=p.id AND s.source_steam_id=p.steam_id::text
WHERE p.id=p_user_id AND p.merged_into_user_id IS NULL
 AND (p.show_on_leaderboard OR p.id=auth.uid() OR auth.role()='service_role');
$$;

COMMIT;
