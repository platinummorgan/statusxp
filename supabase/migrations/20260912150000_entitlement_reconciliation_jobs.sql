BEGIN;
CREATE TABLE IF NOT EXISTS public.entitlement_reconciliation_jobs (
  provider text NOT NULL CHECK(provider IN ('apple','twitch')),
  subject text NOT NULL,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  next_attempt_at timestamptz NOT NULL DEFAULT now(),
  lease_token uuid,
  lease_expires_at timestamptz,
  attempts integer NOT NULL DEFAULT 0,
  last_success_at timestamptz,
  last_failure_at timestamptz,
  PRIMARY KEY(provider,subject)
);
CREATE INDEX IF NOT EXISTS entitlement_reconciliation_due_idx ON public.entitlement_reconciliation_jobs(next_attempt_at);
ALTER TABLE public.entitlement_reconciliation_jobs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.entitlement_reconciliation_jobs FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.entitlement_reconciliation_jobs TO service_role;

CREATE OR REPLACE FUNCTION public.sync_entitlement_reconciliation_job()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p text; old_subject text; new_subject text; u uuid;
BEGIN
  IF TG_TABLE_NAME='twitch_account_bindings' THEN
    p:='twitch';
    IF TG_OP<>'INSERT' THEN old_subject:=OLD.twitch_user_id; END IF;
    IF TG_OP<>'DELETE' THEN new_subject:=NEW.twitch_user_id; u:=NEW.user_id; END IF;
  ELSE
    p:='apple';
    IF TG_OP<>'INSERT' AND OLD.platform='app_store' THEN old_subject:=OLD.subscription_key; END IF;
    IF TG_OP<>'DELETE' AND NEW.platform='app_store' THEN new_subject:=NEW.subscription_key; u:=NEW.user_id; END IF;
  END IF;
  IF old_subject IS NOT NULL AND (new_subject IS DISTINCT FROM old_subject OR u IS NULL) THEN
    DELETE FROM public.entitlement_reconciliation_jobs WHERE provider=p AND subject=old_subject;
  END IF;
  IF new_subject IS NOT NULL AND u IS NOT NULL THEN
    INSERT INTO public.entitlement_reconciliation_jobs(provider,subject,user_id) VALUES(p,new_subject,u)
      ON CONFLICT(provider,subject) DO UPDATE SET user_id=EXCLUDED.user_id,
        next_attempt_at=now(),lease_token=NULL,lease_expires_at=NULL,attempts=0,last_success_at=NULL,last_failure_at=NULL
      WHERE public.entitlement_reconciliation_jobs.user_id IS DISTINCT FROM EXCLUDED.user_id;
  END IF;
  RETURN NULL;
END;
$$;
REVOKE ALL ON FUNCTION public.sync_entitlement_reconciliation_job() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS reconcile_bound_twitch ON public.twitch_account_bindings;
CREATE TRIGGER reconcile_bound_twitch AFTER INSERT OR UPDATE OR DELETE ON public.twitch_account_bindings
FOR EACH ROW EXECUTE FUNCTION public.sync_entitlement_reconciliation_job();
DROP TRIGGER IF EXISTS reconcile_bound_store ON public.store_subscription_bindings;
CREATE TRIGGER reconcile_bound_store AFTER INSERT OR UPDATE OR DELETE ON public.store_subscription_bindings
FOR EACH ROW EXECUTE FUNCTION public.sync_entitlement_reconciliation_job();
INSERT INTO public.entitlement_reconciliation_jobs(provider,subject,user_id)
  SELECT 'twitch',twitch_user_id,user_id FROM public.twitch_account_bindings ON CONFLICT DO NOTHING;
INSERT INTO public.entitlement_reconciliation_jobs(provider,subject,user_id)
  SELECT 'apple',subscription_key,user_id FROM public.store_subscription_bindings WHERE platform='app_store' AND user_id IS NOT NULL
  ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION public.claim_entitlement_reconciliation(p_providers text[],p_include_sandbox boolean DEFAULT false)
RETURNS SETOF public.entitlement_reconciliation_jobs LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE job public.entitlement_reconciliation_jobs%ROWTYPE;
BEGIN
  SELECT * INTO job FROM public.entitlement_reconciliation_jobs
    WHERE provider=ANY(p_providers) AND next_attempt_at<=clock_timestamp()
      AND (lease_expires_at IS NULL OR lease_expires_at<=clock_timestamp())
      AND (p_include_sandbox OR provider<>'apple' OR subject NOT LIKE 'sandbox:%')
    ORDER BY next_attempt_at,provider,subject FOR UPDATE SKIP LOCKED LIMIT 1;
  IF NOT FOUND THEN RETURN; END IF;
  RETURN QUERY UPDATE public.entitlement_reconciliation_jobs SET lease_token=gen_random_uuid(),
    lease_expires_at=clock_timestamp()+interval '2 minutes', attempts=least(attempts+1,30)
    WHERE provider=job.provider AND subject=job.subject RETURNING *;
END;
$$;
CREATE OR REPLACE FUNCTION public.finish_entitlement_reconciliation(p_provider text,p_subject text,p_lease uuid,p_success boolean)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE changed integer;
BEGIN
  IF p_success IS NULL THEN RAISE EXCEPTION 'Missing result'; END IF;
  UPDATE public.entitlement_reconciliation_jobs SET
    next_attempt_at=clock_timestamp()+CASE WHEN p_success THEN interval '6 hours'
      ELSE make_interval(secs=>least(21600,60*power(2,least(attempts-1,9)))::integer) END,
    last_success_at=CASE WHEN p_success THEN clock_timestamp() ELSE last_success_at END,
    last_failure_at=CASE WHEN NOT p_success THEN clock_timestamp() ELSE last_failure_at END,
    attempts=CASE WHEN p_success THEN 0 ELSE attempts END, lease_token=NULL,lease_expires_at=NULL
    WHERE provider=p_provider AND subject=p_subject AND lease_token=p_lease AND lease_expires_at>clock_timestamp();
  GET DIAGNOSTICS changed=ROW_COUNT;
  RETURN changed=1;
END;
$$;
REVOKE ALL ON FUNCTION public.claim_entitlement_reconciliation(text[],boolean),public.finish_entitlement_reconciliation(text,text,uuid,boolean) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.claim_entitlement_reconciliation(text[],boolean),public.finish_entitlement_reconciliation(text,text,uuid,boolean) TO service_role;
COMMIT;
