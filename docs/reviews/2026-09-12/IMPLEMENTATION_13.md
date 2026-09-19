# Batch 13 — SX-015 verified Twitch bindings and fallback

Implemented locally on September 12, 2026. No deployment or live account changes. SX-015 remains in progress.

Twitch ownership now has a dedicated table writable only through a service-role binding function. The OAuth callback passes the verified Twitch identity to that function. Database constraints prevent two app accounts from owning the same Twitch account and require disconnecting before changing to a different Twitch identity. Repeat linking of the same identity is safe. Binding and profile display updates commit together.

A profile trigger rejects changes that disagree with the verified binding, even if an existing profile policy allows broad updates. Existing unchanged profile values are preserved. Webhook fulfillment, subscription checks, and administrator reconciliation use verified bindings instead of trusting profile fields. Provider observations received before binding remain available without granting an app account access.

The common effective-premium lookup now falls back to bound Twitch coverage after other coverage expires, including the existing bounded grace period. A newer expired Twitch observation overrides stale premium flags. App premium reads, AI credit decisions, and provider quota admission inherit this behavior through the shared lookup.

Disconnect removes the binding, clears its profile mirror, and expires the legacy Twitch projection in one transaction. Other premium sources survive. A webhook rechecks ownership after acquiring the user lock, preventing a queued event from restoring access after disconnect. Both the Twitch service and Settings use this operation. Settings offers a reconnect action when an old profile link lacks verified ownership.

Validation:

- [Combined PostgreSQL fixture](../../../supabase/functions/twitch-eventsub-webhook/binding_test.sql) passed twice-applied migration, profile forgery rejection, ownership conflicts, repeat linking, unbound observations, fallback, grace, stale events, cancellation suppression, permissions, disconnect, and verified re-link. It also reruns batch 12's Stripe, AI, and quota assertions. [Evidence](implementation-13-postgres.txt).
- [Independent-connection race test](../../../supabase/functions/twitch-eventsub-webhook/binding_concurrency_test.cjs) confirmed the webhook was waiting on the user lock, committed disconnect, then verified no restored entitlement and a completed event receipt.
- Eleven Twitch Deno tests and three changed Edge entrypoint type checks passed.
- Flutter analysis is clean. Full native suite: 77 passed, nine web-only tests skipped. Live OAuth and the web reconnect interaction remain unverified; no browser or release-build check repeated in this batch.

Manual deployment prerequisites: inspect production definitions and apply prior AI/quota/Stripe/Twitch migrations plus batch 12 before `20260912110000_twitch_account_bindings.sql`. Coordinate this migration with the link/check/backfill functions and Flutter client. Older clients that directly clear the Twitch profile field will be rejected once the guard is active; plan the client cutover before enabling it. Follow the repository manual migration policy; do not run `supabase db push --linked`.

Do not automatically backfill ownership from historically editable profile IDs. Existing users must reconnect through OAuth, or an operator must independently verify ownership before invoking the trusted binding function. Existing legacy entitlement windows are retained until expiry/reconciliation; legacy nonexpiring grants still need review. Unverified links no longer receive webhook renewal grants or appear in the bound-account reconciliation job. Plan and validate that transition before deployment.

Remaining work: Apple/Google source records and lifecycle notifications, scheduled provider renewal checks, legacy ownership/entitlement reconciliation, and complete live purchase/renewal/refund/grace/restore/account-binding verification. This narrows the Twitch identity gap in SX-002 but does not complete the broader profile credential/identity isolation task.
