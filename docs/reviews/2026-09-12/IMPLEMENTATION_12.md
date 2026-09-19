# Batch 12 — SX-015 effective Stripe fallback

Implemented locally on September 12, 2026. SX-015 remains in progress; nothing deployed.

An expired Apple, Google, or Twitch projection previously hid an independently active Stripe subscription. A shared database lookup now preserves a valid existing non-Stripe entitlement, then falls back to active, unexpired Stripe subscriptions using the durable customer binding. Once Stripe subscription records exist, a stale legacy Stripe flag cannot override a cancellation. Legacy Stripe grants without subscription records retain their prior behavior pending cutover reconciliation. Existing null-expiry legacy grants are preserved.

The app's subscription and sync premium reads, AI reservation and credit badge, and provider quota admission use this common decision. Expiry is evaluated when requested, so Stripe fallback does not require an expiry job. Cached screens still need their normal refresh; this does not add an expiry timer. Stripe fallback returns no invented subscription start date.

The client RPC takes no user ID and reads the authenticated account. The parameterized helper is restricted to the service role; the AI credit badge now explicitly rejects requests for another account. Source tables remain inaccessible to clients. A customer index supports the Stripe lookup.

Validation:

- PostgreSQL 18 isolated fixture passed migration reapplication, exact expiry boundary, fallback, cancellation suppression, overlapping subscriptions, legacy compatibility, authenticated account isolation, anonymous denial, and service-role access.
- Integration assertions verify premium AI reservation and sync quota treatment during fallback, then free treatment after expiry. See [SQL evidence](implementation-12-postgres.txt) and [fixture](../../../supabase/functions/stripe-webhook/effective_premium_test.sql).
- Flutter analysis: no issues. Full native suite: 77 passed, nine web-only tests skipped. No web build or browser check repeated for these RPC substitutions.

Deployment: inspect the actual database definitions first, following the manual migration policy. Apply the prior AI reservation, provider quota, and Stripe fulfillment migrations before `20260912100000_effective_premium.sql`; apply this migration before releasing the changed Flutter client. The new migration replaces the relevant functions using their locally reviewed definitions, so reconcile any production-only changes before applying. Legacy Stripe mapping/reconciliation requirements from batch 09 still apply. Do not use `supabase db push --linked`.

Remaining SX-015 work: durable user-bound Twitch fallback, source-specific Apple/Google lifecycle records and notification ingestion, provider renewal reconciliation scheduling, and complete cross-provider purchase/renewal/refund/grace/restore/account-binding verification. This batch deliberately does not infer ownership by dynamically joining editable Twitch profile fields. Existing raw premium projection readers outside the updated application paths and legacy database jobs need live inventory before unified lifecycle work can be declared complete.
