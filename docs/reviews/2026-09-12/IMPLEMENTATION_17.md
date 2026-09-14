# Batch 17 — SX-015 scheduled Apple and Twitch reconciliation

Implemented locally on September 12, 2026. No deployment, worker activation, live provider request, or account mutation. SX-015 remains in progress.

Verified Apple and Twitch account bindings now create durable reconciliation jobs. The migration seeds existing verified bindings and preserves schedules when reapplied. Disconnecting a binding or deleting its account removes its job. Legacy profile fields do not establish ownership or create jobs; Google token hashes are not sufficient for a current-status API lookup.

The service-only queue claims one due job using a two-minute lease and `FOR UPDATE SKIP LOCKED`. Successful checks schedule another check six hours later. Failures retry after one minute, doubling to a six-hour cap. Expired leases can be reclaimed; an old lease cannot settle the replacement. Ownership changes reset the job. Client roles cannot read or mutate this queue.

The new `reconcile-premium-entitlements` Edge function uses the shared admin gate and takes work from the database. It fetches current Twitch status or signed Apple subscription status through the existing provider helpers and applies the existing ordered, account-bound entitlement updates. Provider failures leave access unchanged and schedule a retry. Each invocation processes at most one job. Only providers with all required configuration are claimed, and the response identifies the configured providers. Unconfigured providers remain due.

The existing sync worker can invoke the endpoint immediately and every minute, processing at most five sequential jobs per tick. Overlapping ticks are skipped, requests time out after 90 seconds, and stopping the poller aborts its request. Logs omit provider responses and credentials. The worker is disabled unless explicitly configured.

Validation:

- Nineteen Deno tests passed: four runner tests covering empty queues, settlement order, provider failures, and lost leases/settlement errors, plus fifteen shared admin-gate tests. The new Edge entrypoint type-checks.
- All 21 sync-service Node tests passed, including four new worker tests for configuration, authentication, batch bounds, idle behavior, overlap, cancellation, redaction, and recovery. The four focused tests passed again after the timeout-controller adjustment; worker entrypoint syntax checks passed.
- The combined PostgreSQL fixture passed migration reapplication, verified-binding seeding, schedule preservation, provider/sandbox filters, permissions, retry delays, expired leases, stale settlement rejection, success scheduling, disconnects, and account deletion. Earlier entitlement fixtures also passed. See [database evidence](implementation-17-postgres.txt).
- Two independent database connections competed for one job: exactly one acquired it. Successful settlement prevented an immediate second claim.
- Flutter files were unchanged; browser, device, Flutter suites, and release builds were not repeated. Live provider delivery, Apple OCSP behavior, worker throughput, and deployed scheduling remain unverified.

Deployment and activation:

1. Inspect live definitions and complete the prerequisites through batch 16. Apply `supabase/migrations/20260912150000_entitlement_reconciliation_jobs.sql` manually under the repository migration policy; do not use `supabase db push --linked`.
2. Deploy `reconcile-premium-entitlements` with its shared modules. Keep the default Supabase JWT gateway enabled. The worker uses the Supabase service-role key and the endpoint also checks the shared admin gate.
3. Configure Twitch's `TWITCH_CLIENT_ID`, `TWITCH_BROADCASTER_ID`, and `TWITCH_BROADCASTER_TOKEN`; configure Apple's `APPLE_APP_STORE_ISSUER_ID`, `APPLE_APP_STORE_KEY_ID`, `APPLE_APP_STORE_PRIVATE_KEY`, and numeric `APPLE_APP_STORE_APP_ID`. The existing provider requirements from batches 13 and 16 still apply. Missing provider configuration excludes that provider from claims.
4. Apple sandbox jobs are excluded unless the Edge environment sets `ENTITLEMENT_RECONCILIATION_SANDBOX=true`. This is separate from the Apple notification endpoint's sandbox flag.
5. Deploy the sync service with its existing `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`. After verifying the endpoint, set `ENTITLEMENT_RECONCILIATION_ENABLED=true` to activate polling. No such configuration was changed in this batch.
6. Check due-job age, failures, expired leases, configured provider coverage, and provider quotas before cutover. Five calls per minute and six-hour rechecks are initial bounds, not a measured capacity guarantee; slow requests reduce throughput. Size workers and cadence against the actual binding count. Disabling polling preserves queued jobs for recovery.

Remaining SX-015 work: private Google purchase-token storage and scheduled Google reconciliation, Stripe scheduling, consumable refund/action handling, legacy ownership cutover, and the full live lifecycle matrix. This queue recovers current Apple/Twitch subscription state; it does not implement notification-history replay or consumable refund recovery.
