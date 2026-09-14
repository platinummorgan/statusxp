# Batch 11 — Entitlement lifecycle inventory and expiry fixes

SX-015 remains **in progress**. This batch implements the immediate expiry and Twitch-link fixes; it does not claim unified cross-provider lifecycle handling. No deployment or live provider/account changes were performed.

## Implemented locally

- `hasActivePremium` supplies one client expiry rule for subscription access, entitlement details, and sync premium checks. A revoked flag denies access even with a future expiry. Expired, malformed, and exact-boundary expiries deny access. Null expiry preserves existing legacy/non-expiring grants until their ownership and lifecycle can be reconciled. The methods also discard results if the account changed during the request.
- Google and Apple subscription verification now require a finite future expiry before fulfillment. Google previously allowed a missing expiry to become a non-expiring premium grant. Consumable purchases remain separate from subscription expiry validation.
- Twitch linking no longer has a separate premium upsert or adds months to existing access. It calls the reconciliation path shared by EventSub, manual checks, and backfill. The obsolete broadcaster-token call to the user-subscription endpoint was removed from linking.
- A temporary subscription-check failure after successful Twitch linking returns a successful link with `subscriptionCheckPending`. The app displays that verification is pending instead of asking the user to subscribe or reuse an already-consumed OAuth code. Current access is not revoked because a provider check failed.

These client checks run when entitlement state is fetched. They do not add an expiry timer to every open/cached screen or replace server enforcement. The prior AI and sync quota migrations already check expiry server-side; other premium-dependent database paths still need auditing.

## Repository lifecycle inventory

| Source | Current durable data / update path | Remaining gap |
| --- | --- | --- |
| Stripe | Customer mapping, individual subscription snapshots, event receipts and fulfillment keys from SX-013. Current-state retrieval on webhook events. | Effective fallback when another source expires; refunds/disputes and explicit grace policy; legacy customer/purchase reconciliation. |
| Twitch | Message receipts and observed subscription state from SX-014. Webhook, manual check, backfill, and now initial linking use shared reconciliation. | Scheduled renewal checks, broadcaster token renewal, expiry projection throughout the app, and fallback between sources. |
| Google Play | `verify-store-purchase` verifies subscriptions v2 and stores verified purchase events; fulfillment writes the shared premium row. | No repository RTDN/Pub/Sub handler found. Durable subscription-token lineage/ownership, offline renewal/cancellation/refund ingestion, and source-specific current state are still needed. |
| App Store | Server API transaction verification, verified purchase events, and original transaction ID metadata. Revoked or expired submitted transactions are rejected. | No repository App Store Server Notifications handler found. Durable original-transaction ownership, validated notification ingestion, grace/refund updates, and source-specific state are still needed. |
| Effective premium | `user_premium_status` remains a single shared projection; newer Stripe/Twitch handlers protect other active sources. | A common projection must retain all verified sources and select active fallback access at expiry, rather than relying on the last writer. |

The inventory is repository-only. Existing externally configured jobs, webhook destinations, provider notification settings, and production schema have not been verified. Absence from this repository does not establish their absence in production.

## Remaining SX-015 work

1. Introduce a source-specific entitlement ledger and one effective-access projection with stable external subscription keys, immutable account binding, event ordering, and an expiry-aware fallback policy. Migrate verified existing records without inventing owners or granting legacy purchases twice.
2. Implement and test authenticated Apple/Google lifecycle notification ingestion and recovery. Provider failures must remain retryable; expiry, refund, revocation, renewal, cancellation, and grace must be represented independently of client restore activity.
3. Reconcile all premium writers/readers, including legacy RPCs, profile-link ownership, scheduled Twitch checks, and cached UI state. Coordinate profile ownership with SX-002 and client grant retirement with SX-003.
4. Validate the full lifecycle matrix for purchase, renewal, cancellation, refund, grace, restore, account switching/binding, and overlapping sources, then verify controlled provider test-mode flows. Keep SX-015 open until these are covered.

## Validation and rollout

- 77 Flutter tests pass, with nine web-only tests skipped. New regressions cover exact expiry boundaries, timezones, revoked/malformed/non-expiring grants, and successful Twitch linking while subscription verification is pending.
- 13 Deno tests pass, including new store-expiry validation and the existing Twitch verification/reconciliation regression tests. Both modified Edge entrypoints type-check.
- Static analysis is clean. Outputs are saved as `implementation-11-analysis.txt`, `implementation-11-flutter-tests.txt`, `implementation-11-deno-tests.txt`, `implementation-11-typecheck.txt`, and `implementation-11-web-build.txt`.
- The release web build passes; existing optional Wasm dry-run warnings remain.
- Deploy the Twitch link function with the new Flutter pending-verification display and the SX-014 reconciliation migration/functions. Deploy the stricter store-verification function after confirming real store responses supply their expected expiry fields. No new database migration is required for this batch.

No real store purchases, refunds, restores, or Twitch API calls were used for validation. Legacy non-expiring rows are preserved, not independently validated or certified by this change.
