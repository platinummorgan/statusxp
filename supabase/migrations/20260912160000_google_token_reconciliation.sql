BEGIN;
CREATE TABLE IF NOT EXISTS public.google_play_tokens (
  subscription_key text PRIMARY KEY CHECK(subscription_key ~ '^(production|sandbox):[0-9a-f]{64}$'),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  envelope jsonb NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.google_play_tokens ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.google_play_tokens FROM PUBLIC,anon,authenticated,service_role;
GRANT SELECT ON public.google_play_tokens TO service_role;
ALTER TABLE public.entitlement_reconciliation_jobs DROP CONSTRAINT IF EXISTS entitlement_reconciliation_jobs_provider_check;
ALTER TABLE public.entitlement_reconciliation_jobs ADD CONSTRAINT entitlement_reconciliation_jobs_provider_check CHECK(provider IN ('apple','twitch','google'));

CREATE OR REPLACE FUNCTION public.save_google_play_token(p_subject text,p_user uuid,p_envelope jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('store:google_play',0));
  PERFORM 1 FROM auth.users WHERE id=p_user FOR UPDATE;
  IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM public.store_subscription_bindings WHERE platform='google_play' AND subscription_key=p_subject AND user_id=p_user) THEN
    RAISE EXCEPTION 'Verified Google binding required';
  END IF;
  IF p_envelope IS NULL OR jsonb_typeof(p_envelope)<>'object' OR
    p_envelope->>'version' IS DISTINCT FROM '1' OR
    COALESCE(p_envelope->>'keyId','') !~ '^[a-zA-Z0-9_-]{1,64}$' OR
    COALESCE(p_envelope->>'iv','') !~ '^[A-Za-z0-9+/]{16}$' OR
    COALESCE(p_envelope->>'ciphertext','') !~ '^[A-Za-z0-9+/]+={0,2}$' OR
    length(p_envelope->>'ciphertext') NOT BETWEEN 24 AND 86000 OR
    (p_envelope - ARRAY['version','keyId','iv','ciphertext']) <> '{}'::jsonb THEN
    RAISE EXCEPTION 'Invalid encrypted token';
  END IF;
  INSERT INTO public.google_play_tokens(subscription_key,user_id,envelope) VALUES(p_subject,p_user,p_envelope)
    ON CONFLICT(subscription_key) DO UPDATE SET envelope=EXCLUDED.envelope,updated_at=now()
    WHERE public.google_play_tokens.user_id=EXCLUDED.user_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Token owner changed'; END IF;
  INSERT INTO public.entitlement_reconciliation_jobs(provider,subject,user_id) VALUES('google',p_subject,p_user)
    ON CONFLICT DO NOTHING;
END;
$$;
REVOKE ALL ON FUNCTION public.save_google_play_token(text,uuid,jsonb) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.cleanup_google_play_token()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF OLD.platform='google_play' AND (TG_OP='DELETE' OR NEW.user_id IS DISTINCT FROM OLD.user_id OR NEW.subscription_key IS DISTINCT FROM OLD.subscription_key OR NEW.platform IS DISTINCT FROM OLD.platform) THEN
    DELETE FROM public.google_play_tokens WHERE subscription_key=OLD.subscription_key;
    DELETE FROM public.entitlement_reconciliation_jobs WHERE provider='google' AND subject=OLD.subscription_key;
  END IF;
  RETURN NULL;
END;
$$;
REVOKE ALL ON FUNCTION public.cleanup_google_play_token() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS cleanup_google_token_binding ON public.store_subscription_bindings;
CREATE TRIGGER cleanup_google_token_binding AFTER UPDATE OR DELETE ON public.store_subscription_bindings FOR EACH ROW EXECUTE FUNCTION public.cleanup_google_play_token();

CREATE OR REPLACE FUNCTION public.fulfill_google_purchase_with_token(
  p_user_id uuid,p_platform text,p_transaction_id text,p_product_id text,p_product_type text,p_store_state text,
  p_purchased_at timestamptz,p_expires_at timestamptz,p_is_test boolean,p_metadata jsonb,p_token_envelope jsonb
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;
BEGIN
  IF p_platform IS DISTINCT FROM 'google_play' OR p_product_type IS DISTINCT FROM 'subscription' THEN RAISE EXCEPTION 'Google subscription required'; END IF;
  result:=public.fulfill_verified_store_purchase(p_user_id,p_platform,p_transaction_id,p_product_id,p_product_type,p_store_state,p_purchased_at,p_expires_at,p_is_test,p_metadata);
  PERFORM public.save_google_play_token(p_metadata->>'subscriptionKey',p_user_id,p_token_envelope);
  RETURN result;
END;
$$;
REVOKE ALL ON FUNCTION public.fulfill_google_purchase_with_token(uuid,text,text,text,text,text,timestamptz,timestamptz,boolean,jsonb,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.fulfill_google_purchase_with_token(uuid,text,text,text,text,text,timestamptz,timestamptz,boolean,jsonb,jsonb) TO service_role;

CREATE OR REPLACE FUNCTION public.apply_google_notification_with_token(
  p_message_id text,p_body_hash text,p_observed_at timestamptz,p_snapshot jsonb,p_expected_user uuid,p_token_envelope jsonb
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  PERFORM public.apply_google_play_notification(p_message_id,p_body_hash,p_observed_at,p_snapshot,p_expected_user);
  IF p_snapshot IS NOT NULL AND p_expected_user IS NOT NULL THEN
    PERFORM public.save_google_play_token(p_snapshot->>'subscriptionKey',p_expected_user,p_token_envelope);
  END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.apply_google_notification_with_token(text,text,timestamptz,jsonb,uuid,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.apply_google_notification_with_token(text,text,timestamptz,jsonb,uuid,jsonb) TO service_role;
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
