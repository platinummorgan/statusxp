BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='120s';
CREATE OR REPLACE FUNCTION public.review_steam_completion_set(p_app_id text,p_required_ids text[],p_excluded_ids text[],p_evidence jsonb)
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
   OR COALESCE(p_evidence->>'scope','') NOT IN('day_one_base_game','console_equivalent_base_game')
   OR jsonb_array_length(COALESCE(p_evidence->'sources','[]'))=0 THEN
   RAISE EXCEPTION 'A nonempty complete base classification with source evidence is required';
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
 UPDATE public.steam_completion_catalog SET rarity_source=CASE WHEN p_evidence->>'scope'='console_equivalent_base_game' THEN 'estimated_minimum_console_equivalent_base_game' ELSE 'estimated_minimum_day_one_base_game' END WHERE platform_game_id=p_app_id;
END; $$;

CREATE OR REPLACE FUNCTION public.finish_steam_completion_review_job(p_app_id text,p_lease_token uuid,p_proposal jsonb,p_error text DEFAULT NULL)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE j public.steam_completion_review_jobs%ROWTYPE;c public.steam_completion_catalog%ROWTYPE;
 v_source public.steam_completion_catalog%ROWTYPE; v_required text[];v_excluded text[];
 v_count integer;v_matches integer;v_status text;
BEGIN
 -- Catalog first matches the lock order of catalog updates and their queue trigger.
 SELECT * INTO c FROM public.steam_completion_catalog WHERE platform_game_id=p_app_id FOR UPDATE;
 SELECT * INTO j FROM public.steam_completion_review_jobs WHERE platform_game_id=p_app_id FOR UPDATE;
 IF j.lease_token IS DISTINCT FROM p_lease_token OR p_lease_token IS NULL OR j.leased_until<now() THEN RETURN false; END IF;
 IF c.review_state='verified' THEN v_status:='skipped';
 ELSIF p_error IS NOT NULL OR p_proposal IS NULL THEN v_status:='error';
 ELSE
  IF p_proposal->>'app_id' IS DISTINCT FROM p_app_id
   OR COALESCE(p_proposal->>'status','') NOT IN('ready_for_review','needs_review')
   OR jsonb_typeof(p_proposal->'observed_ids') IS DISTINCT FROM 'array'
   OR jsonb_typeof(p_proposal->'native_definitions') IS DISTINCT FROM 'array' THEN
   RAISE EXCEPTION 'Invalid Steam review result';
  END IF;
  v_status:=p_proposal->>'status';
  INSERT INTO public.steam_completion_schema_snapshots(platform_game_id,signature,source,snapshot)
  VALUES(p_app_id,md5((p_proposal->'native_definitions')::text),'public_steam_schema',
   jsonb_build_object('observed_ids',p_proposal->'observed_ids','definitions',p_proposal->'native_definitions',
    'groups',p_proposal->'groups','release',p_proposal->'release','schema_version',p_proposal->'schema_version'))
  ON CONFLICT(platform_game_id,signature,source) DO UPDATE SET last_seen_at=now();
  -- Never undo a hand-flagged exception, or approve a mismatched native snapshot.
  IF c.review_state='pending' AND c.evidence='{}'::jsonb
   AND (p_proposal->>'coverage_complete')::boolean IS TRUE
   AND ARRAY(SELECT jsonb_array_elements_text(p_proposal->'observed_ids') ORDER BY 1)=c.observed_ids
   AND jsonb_typeof(p_proposal->'native_definitions')='array'
   AND jsonb_array_length(p_proposal->'native_definitions')=cardinality(c.observed_ids)
   AND NOT EXISTS(SELECT 1 FROM public.achievements a WHERE a.platform_id=4 AND a.platform_game_id=p_app_id
    AND (SELECT count(*) FROM jsonb_array_elements(p_proposal->'native_definitions') n
     WHERE n->>'id'=a.platform_achievement_id AND n->>'name'=a.name
     AND btrim(COALESCE(n->>'description',''))=btrim(COALESCE(a.description,'')))<>1) THEN
   SELECT count(*) INTO v_count FROM public.achievements WHERE platform_id=4 AND platform_game_id=p_app_id;
   FOR v_source IN
    SELECT sc.* FROM public.steam_completion_catalog sc
    JOIN public.games sg ON sg.platform_id=4 AND sg.platform_game_id=sc.platform_game_id
    JOIN public.games tg ON tg.platform_id=4 AND tg.platform_game_id=p_app_id
    WHERE sc.review_state='verified' AND sc.platform_game_id<>p_app_id
    AND lower(btrim(sg.name))=lower(btrim(tg.name))
    AND sc.evidence->>'review_method' IS DISTINCT FROM 'automatic_identical_reviewed_steam_set'
    ORDER BY sc.platform_game_id FOR SHARE OF sc
   LOOP
    IF cardinality(v_source.required_ids||v_source.excluded_ids)<>v_count THEN CONTINUE; END IF;
    -- Reciprocal unique names and descriptions: no fuzzy title/requirement matching.
    IF EXISTS(SELECT 1 FROM public.achievements a WHERE a.platform_id=4
      AND a.platform_game_id IN(p_app_id,v_source.platform_game_id)
      GROUP BY a.platform_game_id,lower(btrim(a.name)) HAVING count(*)<>1) THEN CONTINUE; END IF;
    SELECT count(*),array_agg(t.platform_achievement_id ORDER BY t.platform_achievement_id)
      FILTER(WHERE s.platform_achievement_id=ANY(v_source.required_ids)),
      COALESCE(array_agg(t.platform_achievement_id ORDER BY t.platform_achievement_id)
      FILTER(WHERE s.platform_achievement_id=ANY(v_source.excluded_ids)),'{}')
     INTO v_matches,v_required,v_excluded
    FROM public.achievements t JOIN public.achievements s
     ON s.platform_id=4 AND s.platform_game_id=v_source.platform_game_id
     AND lower(btrim(t.name))=lower(btrim(s.name))
     AND btrim(COALESCE(t.description,''))<>''
     AND btrim(t.description)=btrim(s.description)
    WHERE t.platform_id=4 AND t.platform_game_id=p_app_id
     AND s.platform_achievement_id=ANY(v_source.required_ids||v_source.excluded_ids);
    IF v_matches=v_count AND cardinality(v_required)>0
      AND cardinality(v_required||v_excluded)=v_count THEN
     PERFORM public.review_steam_completion_set(p_app_id,v_required,v_excluded,
      jsonb_build_object('scope',v_source.evidence->>'scope','review_method','automatic_identical_reviewed_steam_set',
       'sources',v_source.evidence->'sources','source_app_id',v_source.platform_game_id,
       'source_revision',v_source.membership_revision,'reviewed_date',CURRENT_DATE));
     v_status:='approved'; EXIT;
    END IF;
   END LOOP;
  END IF;
 END IF;
 UPDATE public.steam_completion_review_jobs SET status=v_status,proposal=p_proposal,
  last_error=CASE WHEN v_status='error' THEN 'Provider evidence or catalog unavailable' ELSE NULL END,
  analyzed_at=now(),updated_at=now(),lease_token=NULL,leased_until=NULL,
  next_attempt_at=now()+CASE WHEN v_status='error' THEN interval '30 minutes' ELSE interval '7 days' END
 WHERE platform_game_id=p_app_id;
 RETURN true;
END $$;
SELECT public.review_steam_completion_set('252330',ARRAY['COLLECTOR_ACHIEVEMENT_1','COLLECTOR_ACHIEVEMENT_2','CRYBABY_ACHIEVEMENT_1','FEARLESS_ACHIEVEMENT_1','FIREPROOF_ACHIEVEMENT_1','ILLTAKEIT_ACHIEVEMENT_1','IMFREE_ACHIEVEMENT_1','INSTAKILLED_ACHIEVEMENT_1','MARATHON_ACHIEVEMENT_1','PAUSE_ACHIEVEMENT_1','PAUSE_ACHIEVEMENT_2','PIANO_ACHIEVEMENT_1','RADIO_ACHIEVEMENT_1','RETRO_ACHIEVEMENT_1','SLIDE_ACHIEVEMENT_1','SPEED_ACHIEVEMENT_1','SPEED_ACHIEVEMENT_2','SPEED_ACHIEVEMENT_3','TANGLED_ACHIEVEMENT_1','YOUTRIED_ACHIEVEMENT_1']::text[],ARRAY['ESCAPED_ACHIEVEMENT_1']::text[],'{"scope":"console_equivalent_base_game","membership_policy":"verified_console_completion_equivalent","reviewed_date":"2026-11-16","reference_platform_id":1,"reference_game_id":"NPWR38903_00","reference_regular_trophy_count":20,"reference_platinum_included_in_count":false,"sources":["psn:1:NPWR38903_00","https://steamcommunity.com/achievements/252330/?l=english","https://psnprofiles.com/guide/18583-slender-the-arrival-trophy-guide"],"review_method":"User confirmed that earning the equivalent PS5 Platinum requirements qualifies Steam base completion. Twenty regular PS5 trophies map to Steam IDs; the PS5 Platinum itself is the completion award. Steam-only I Escaped? is excluded from eligibility and estimated rarity even if original to Steam.","source_access":"PSNProfiles returned HTTP 403 to automated retrieval. The native synced PS5 definitions and earned Platinum were verified in the database.","requirement_review":"Four renamed requirements map by unique equivalent descriptions. Tangled differs only by the tenticles/tentacles spelling error; its name, action and base grouping agree.","excluded_reason":"ESCAPED_ACHIEVEMENT_1 has no PS5 Platinum requirement counterpart.","schema_hash":877310804,"schema_version":15}'::jsonb);
DO $$ BEGIN ASSERT (SELECT review_state='verified' AND cardinality(required_ids)=20 AND excluded_ids=ARRAY['ESCAPED_ACHIEVEMENT_1'] AND evidence->>'scope'='console_equivalent_base_game' AND rarity_source='estimated_minimum_console_equivalent_base_game' FROM public.steam_completion_catalog WHERE platform_game_id='252330'), 'Slender console equivalent set mismatch'; ASSERT (SELECT estimated_rarity IS NOT DISTINCT FROM (SELECT min(a.rarity_global) FROM public.achievements a WHERE a.platform_id=4 AND a.platform_game_id='252330' AND a.platform_achievement_id=ANY(c.required_ids)) FROM public.steam_completion_catalog c WHERE c.platform_game_id='252330'), 'Slender rarity must use only required trophies'; END $$;
COMMIT;
