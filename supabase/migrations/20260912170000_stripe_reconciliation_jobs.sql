BEGIN;
ALTER TABLE public.entitlement_reconciliation_jobs DROP CONSTRAINT IF EXISTS entitlement_reconciliation_jobs_provider_check;
ALTER TABLE public.entitlement_reconciliation_jobs ADD CONSTRAINT entitlement_reconciliation_jobs_provider_check CHECK(provider IN ('apple','twitch','google','stripe'));

CREATE OR REPLACE FUNCTION public.sync_stripe_reconciliation_job()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE owner_id uuid;
BEGIN
  IF TG_OP='DELETE' THEN
    DELETE FROM public.entitlement_reconciliation_jobs WHERE provider='stripe' AND subject=OLD.subscription_id;
    RETURN NULL;
  END IF;
  IF TG_OP='UPDATE' AND OLD.subscription_id IS DISTINCT FROM NEW.subscription_id THEN
    DELETE FROM public.entitlement_reconciliation_jobs WHERE provider='stripe' AND subject=OLD.subscription_id;
  END IF;
  SELECT user_id INTO owner_id FROM public.stripe_customers WHERE customer_id=NEW.customer_id;
  IF owner_id IS NULL THEN
    DELETE FROM public.entitlement_reconciliation_jobs WHERE provider='stripe' AND subject=NEW.subscription_id;
  ELSE
    INSERT INTO public.entitlement_reconciliation_jobs(provider,subject,user_id) VALUES('stripe',NEW.subscription_id,owner_id)
      ON CONFLICT(provider,subject) DO UPDATE SET user_id=EXCLUDED.user_id,next_attempt_at=now(),
        lease_token=NULL,lease_expires_at=NULL,attempts=0,last_success_at=NULL,last_failure_at=NULL
      WHERE public.entitlement_reconciliation_jobs.user_id IS DISTINCT FROM EXCLUDED.user_id;
  END IF;
  RETURN NULL;
END;
$$;
REVOKE ALL ON FUNCTION public.sync_stripe_reconciliation_job() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS reconcile_stripe_subscription ON public.stripe_subscriptions;
CREATE TRIGGER reconcile_stripe_subscription AFTER INSERT OR UPDATE OR DELETE ON public.stripe_subscriptions
FOR EACH ROW EXECUTE FUNCTION public.sync_stripe_reconciliation_job();

CREATE OR REPLACE FUNCTION public.sync_stripe_customer_reconciliation_jobs()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF OLD.user_id IS DISTINCT FROM NEW.user_id THEN
    DELETE FROM public.entitlement_reconciliation_jobs j USING public.stripe_subscriptions s
      WHERE j.provider='stripe' AND j.subject=s.subscription_id AND s.customer_id=NEW.customer_id;
    IF NEW.user_id IS NOT NULL THEN
      INSERT INTO public.entitlement_reconciliation_jobs(provider,subject,user_id)
        SELECT 'stripe',subscription_id,NEW.user_id FROM public.stripe_subscriptions WHERE customer_id=NEW.customer_id
        ON CONFLICT DO NOTHING;
    END IF;
  END IF;
  RETURN NULL;
END;
$$;
REVOKE ALL ON FUNCTION public.sync_stripe_customer_reconciliation_jobs() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS reconcile_stripe_customer ON public.stripe_customers;
CREATE TRIGGER reconcile_stripe_customer AFTER UPDATE OF user_id ON public.stripe_customers
FOR EACH ROW EXECUTE FUNCTION public.sync_stripe_customer_reconciliation_jobs();
INSERT INTO public.entitlement_reconciliation_jobs(provider,subject,user_id)
  SELECT 'stripe',s.subscription_id,c.user_id FROM public.stripe_subscriptions s JOIN public.stripe_customers c USING(customer_id)
  WHERE c.user_id IS NOT NULL ON CONFLICT DO NOTHING;
CREATE OR REPLACE FUNCTION public.claim_entitlement_reconciliation(p_providers text[],p_include_sandbox boolean DEFAULT false)
RETURNS SETOF public.entitlement_reconciliation_jobs LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE job public.entitlement_reconciliation_jobs%ROWTYPE;
BEGIN
  SELECT * INTO job FROM public.entitlement_reconciliation_jobs
    WHERE provider=ANY(p_providers) AND next_attempt_at<=clock_timestamp()
      AND (lease_expires_at IS NULL OR lease_expires_at<=clock_timestamp())
      AND (p_include_sandbox OR provider NOT IN ('apple','google') OR subject NOT LIKE 'sandbox:%')
    AND (provider<>'google' OR EXISTS (
        SELECT 1 FROM public.google_play_tokens t
        JOIN public.store_subscription_bindings b ON b.platform='google_play' AND b.subscription_key=t.subscription_key AND b.user_id=t.user_id
        JOIN public.google_play_subscription_state g ON g.subscription_key=t.subscription_key
        WHERE t.subscription_key=subject AND t.user_id=entitlement_reconciliation_jobs.user_id AND NOT g.superseded
          AND NOT (g.store_state IN ('SUBSCRIPTION_STATE_EXPIRED','SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED') AND g.expires_at IS NOT NULL AND g.expires_at<clock_timestamp()-interval '60 days')
      ))
    AND (provider<>'stripe' OR EXISTS (
      SELECT 1 FROM public.stripe_subscriptions s JOIN public.stripe_customers c USING(customer_id)
      WHERE s.subscription_id=subject AND c.user_id=entitlement_reconciliation_jobs.user_id
        AND s.status NOT IN ('canceled','incomplete_expired')
    ))
    ORDER BY next_attempt_at,provider,subject FOR UPDATE SKIP LOCKED LIMIT 1;
  IF NOT FOUND THEN RETURN; END IF;
  RETURN QUERY UPDATE public.entitlement_reconciliation_jobs SET lease_token=gen_random_uuid(),
    lease_expires_at=clock_timestamp()+interval '2 minutes', attempts=least(attempts+1,30)
    WHERE provider=job.provider AND subject=job.subject RETURNING *;
END;
$$;
REVOKE ALL ON FUNCTION public.claim_entitlement_reconciliation(text[],boolean) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.claim_entitlement_reconciliation(text[],boolean) TO service_role;
COMMIT;
