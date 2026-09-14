# Batch 19 — SX-015 scheduled Stripe subscription checks

Implemented locally on September 12, 2026. No deployment, scheduler activation, Stripe configuration change, live API request, purchase, or account mutation. SX-015 remains in progress.

Recorded Stripe subscriptions now create durable reconciliation jobs tied to their verified customer/account binding. Existing records are seeded by the migration, and migration reapplication preserves schedules. Subscription removal deletes its job; account deletion removes jobs while retaining the customer tombstone. Normal webhook updates preserve an existing queue lease and due time.

The scheduled endpoint includes Stripe when `STRIPE_SECRET_KEY` is configured. Each job checks its stored customer/account mapping, then acquires the same `subscription:<id>` resource lease used by Stripe webhooks before fetching current subscription state. The resource lease token fences the database commit; the queue lease separately controls retry/scheduling. Busy resources, provider failures, or expired leases leave jobs retryable. A queue attempt uses a stable internal receipt ID derived from its lease token, and completed attempts avoid a second provider lookup.

Current Stripe responses must match the stored subscription, customer, account metadata, supported recurring product, environment, status, and expiry format. The shared webhook resolver supplies the fulfillment snapshot with the expected account fixed to the job's owner. Existing atomic fulfillment applies the current state and retains cross-provider effective access. No payment, cancellation, refund, or other Stripe write API is called.

The scheduler uses the existing Stripe SDK version and pinned API version `2023-10-16`, with a 20-second request timeout and no SDK network retry. The durable queue handles retries. Stripe's SDK supports these [request timeout and retry settings](https://github.com/stripe/stripe-node#configuration). The existing webhook's settings remain unchanged.

Canceled and `incomplete_expired` records are excluded from future claims because those are terminal subscription states. Recoverable states such as `past_due`, `unpaid`, and `paused` remain eligible. This follows Stripe's [subscription status definitions](https://docs.stripe.com/billing/subscriptions/overview#subscription-statuses). The app's existing access policy still grants Stripe coverage only for active, unexpired subscriptions; this batch does not introduce a trial or delinquency grace policy.

Validation:

- 22 Deno tests passed: six scheduled Stripe tests, four queue-runner tests, and twelve webhook handler/resolver regressions. Coverage includes lease-before-lookup ordering, busy/completed attempts, deleted/changed owners, customer/account/product mismatches, malformed state, test-mode gating, negative states, and provider/commit failures.
- The reconciliation and Stripe webhook Edge entrypoints type-check.
- The combined PostgreSQL fixture passed migration reapplication/seeding, schedule preservation, queue/resource lease coordination, renewal, cancellation, terminal/recoverable filtering, account deletion, stale settlement, and permission checks. Earlier combined provider/queue fixtures also passed. See [database evidence](implementation-19-postgres.txt).
- Independent scheduled/webhook database connections acquired exactly one Stripe resource lease. After expiry and a later cancellation commit, the old lease could not restore active access. The terminal subscription was no longer claimable.
- Flutter, browser, device, and Node worker files were unchanged; those suites/builds were not repeated. Live Stripe test-mode delivery and deployed scheduling remain unverified.

Deployment prerequisites:

1. Inspect live definitions and complete prerequisites through batch 18. Apply `supabase/migrations/20260912170000_stripe_reconciliation_jobs.sql` manually under the repository migration policy; do not use `supabase db push --linked`.
2. Deploy the reconciliation endpoint with its updated runner, Stripe helper, and shared webhook resolver. Existing webhook behavior is unchanged; the resolver now exports its subscription normalization function for reuse.
3. Configure the endpoint's existing `STRIPE_SECRET_KEY` for the intended Stripe account. Retain the default Supabase JWT gateway and shared admin gate. The sync worker uses the existing service-role configuration and opt-in `ENTITLEMENT_RECONCILIATION_ENABLED=true` from batch 17.
4. Stripe test-mode responses require `ENTITLEMENT_RECONCILIATION_SANDBOX=true`; without it they fail closed and retry. This flag also includes Apple/Google sandbox jobs. Historical Stripe rows do not contain a mode column, so the current API response enforces this boundary. Use a matching Stripe account/key and monitor identity/environment failures.
5. Verify controlled renewals, cancellation, retries, account deletion, and overlapping webhook delivery before live activation. Monitor queue age and failures, pending internal reconciliation receipts, and expired Stripe resource leases. A failed lookup leaves its resource lease to expire; an early queue retry can therefore encounter a busy resource. Existing six-hour success cadence and bounded worker batches are initial capacity limits, not a measured production guarantee.

Coverage limit: this scheduler refreshes subscriptions already present in `stripe_subscriptions`. It does not list customer subscriptions to discover a purchase whose initial checkout/subscription events never reached the app, backfill historical customer ownership, or recover missed credit-pack fulfillment. Those require separate discovery/replay work. Terminal subscription jobs and internal receipts remain stored; their retention/maintenance policy remains open.

Remaining SX-015 work: initial-purchase discovery/replay, terminal token/receipt maintenance, consumable refund/action handling, legacy ownership/token cutover, and the full live lifecycle matrix. Scheduled refreshes now cover known Apple, Twitch, Google, and Stripe subscriptions locally; production activation remains pending.
