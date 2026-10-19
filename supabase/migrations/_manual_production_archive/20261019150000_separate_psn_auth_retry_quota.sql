-- Apply manually before deploying psn-start-sync; do not db push.
-- Authentication retries retain short/daily abuse limits without consuming
-- the two-hour sync cooldown before credentials have been verified.
BEGIN;
SET LOCAL lock_timeout='5s';
INSERT INTO public.provider_quota_policy
 (provider,free_daily,premium_daily,global_daily,free_cooldown,premium_cooldown)
VALUES ('psn_auth',30,120,20000,10,5)
ON CONFLICT(provider) DO NOTHING;
COMMIT;
