BEGIN;
SET LOCAL lock_timeout='5s';
CREATE TABLE public.steam_completion_review_jobs (
 platform_game_id text PRIMARY KEY REFERENCES public.steam_completion_catalog ON DELETE CASCADE,
 status text NOT NULL DEFAULT 'queued' CHECK(status IN('queued','processing','ready_for_review','needs_review','error','approved','skipped')),
 attempts integer NOT NULL DEFAULT 0,
 next_attempt_at timestamptz NOT NULL DEFAULT now(),
 lease_token uuid, leased_until timestamptz,
 observed_ids text[] NOT NULL DEFAULT '{}',
 proposal jsonb, last_error text, analyzed_at timestamptz,
 updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.steam_completion_review_jobs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.steam_completion_review_jobs FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.steam_completion_review_jobs TO service_role;
CREATE INDEX steam_review_due_idx ON public.steam_completion_review_jobs(next_attempt_at);
CREATE TABLE public.steam_completion_schema_snapshots (
 platform_game_id text NOT NULL REFERENCES public.steam_completion_catalog ON DELETE CASCADE,
 signature text NOT NULL, source text NOT NULL,
 snapshot jsonb NOT NULL,
 first_seen_at timestamptz NOT NULL DEFAULT now(),last_seen_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(platform_game_id,signature,source)
);
ALTER TABLE public.steam_completion_schema_snapshots ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.steam_completion_schema_snapshots FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.steam_completion_schema_snapshots TO service_role;

CREATE FUNCTION public.queue_steam_completion_review() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_snapshot jsonb;
BEGIN
 IF TG_OP='INSERT' OR NEW.observed_ids IS DISTINCT FROM OLD.observed_ids THEN
  SELECT jsonb_build_object('observed_ids',NEW.observed_ids,'definitions',COALESCE(jsonb_agg(
   jsonb_build_object('id',a.platform_achievement_id,'name',a.name,'description',a.description)
   ORDER BY a.platform_achievement_id),'[]')) INTO v_snapshot FROM public.achievements a
   WHERE a.platform_id=4 AND a.platform_game_id=NEW.platform_game_id AND a.platform_achievement_id=ANY(NEW.observed_ids);
  INSERT INTO public.steam_completion_schema_snapshots(platform_game_id,signature,source,snapshot)
  VALUES(NEW.platform_game_id,md5(v_snapshot::text),'native_sync_catalog',v_snapshot)
  ON CONFLICT(platform_game_id,signature,source) DO UPDATE SET last_seen_at=now();
  IF NEW.review_state='verified' THEN RETURN NEW; END IF;
  INSERT INTO public.steam_completion_review_jobs(platform_game_id,observed_ids)
  VALUES(NEW.platform_game_id,NEW.observed_ids)
  ON CONFLICT(platform_game_id) DO UPDATE SET status='queued',next_attempt_at=now(),
   observed_ids=EXCLUDED.observed_ids,lease_token=NULL,leased_until=NULL,updated_at=now();
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER queue_steam_original_membership_review AFTER INSERT OR UPDATE
 ON public.steam_completion_catalog FOR EACH ROW EXECUTE FUNCTION public.queue_steam_completion_review();

CREATE FUNCTION public.claim_steam_completion_review_job()
RETURNS SETOF public.steam_completion_review_jobs
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_id text;
BEGIN
 SELECT j.platform_game_id INTO v_id FROM public.steam_completion_review_jobs j
 JOIN public.steam_completion_catalog c USING(platform_game_id)
 WHERE c.review_state<>'verified' AND j.next_attempt_at<=now()
 AND (j.leased_until IS NULL OR j.leased_until<now())
 ORDER BY j.next_attempt_at,j.platform_game_id FOR UPDATE OF j SKIP LOCKED LIMIT 1;
 IF v_id IS NULL THEN RETURN; END IF;
 RETURN QUERY UPDATE public.steam_completion_review_jobs SET status='processing',attempts=attempts+1,
  lease_token=pg_catalog.gen_random_uuid(),leased_until=now()+interval '10 minutes',updated_at=now()
  WHERE platform_game_id=v_id RETURNING *;
END $$;

-- Only a previously reviewed, byte-equivalent achievement definition set can be
-- copied automatically. Console matches and Steam groups remain review proposals.
CREATE FUNCTION public.finish_steam_completion_review_job(p_app_id text,p_lease_token uuid,p_proposal jsonb,p_error text DEFAULT NULL)
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
      jsonb_build_object('scope','day_one_base_game','review_method','automatic_identical_reviewed_steam_set',
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
REVOKE ALL ON FUNCTION public.queue_steam_completion_review(),public.claim_steam_completion_review_job(),
 public.finish_steam_completion_review_job(text,uuid,jsonb,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.claim_steam_completion_review_job(),
 public.finish_steam_completion_review_job(text,uuid,jsonb,text) TO service_role;
INSERT INTO public.steam_completion_review_jobs(platform_game_id,observed_ids)
 SELECT platform_game_id,observed_ids FROM public.steam_completion_catalog WHERE review_state<>'verified';
COMMIT;
