# Batch 10 — Repeat-safe Twitch entitlements

SX-014 is implemented locally. No live webhook, Twitch account, entitlement, or database was changed. Deployment and real consent/subscription verification remain pending.

## Changes

The EventSub handler verifies HMAC-SHA256 using Web Crypto over the message ID, timestamp, and original body. It rejects messages older than ten minutes or more than one minute ahead of the server clock, caps bodies at 128,000 bytes, checks the configured broadcaster, and returns the verified challenge verbatim. These checks follow [Twitch's webhook authentication guidance](https://dev.twitch.tv/docs/eventsub/handling-webhook-events/).

`20260912090000_twitch_event_receipts.sql` records message IDs, body hashes, and signed timestamps. Receipt insertion and entitlement projection commit together. An already-committed receipt bypasses another API check; concurrent deliveries are also deduplicated by the database. Conflicting IDs fail closed. Per-Twitch-account locking serializes observations, older observations cannot overwrite newer state, and inactive observations win equal timestamps.

Supported subscriber notifications trigger a current broadcaster-subscription lookup before reconciliation. The helper uses `/helix/subscriptions` with the broadcaster user token and requires the exact broadcaster/subscriber pair. Authentication failures, rate limits, malformed results, and outages throw errors; they never become an “unsubscribed” result. Requests time out after ten seconds.

Gift notifications do not grant access to their `user_id`: that ID identifies the donor. Gift recipient access is handled through the recipient's subscribe notification and current-state lookup. Resubscription chat messages also trigger a lookup rather than blindly adding another month. Twitch documents these distinctions in its [EventSub subscription types](https://dev.twitch.tv/docs/eventsub/eventsub-subscription-types/).

An active observation sets expiry to the observation timestamp plus 33 days. It does **not** add 33 days to an existing expiry. A verified inactive observation caps an existing Twitch window at three more days, without extending it; an account with no existing Twitch window receives no new grace access. This is the app's observation-based access policy, not an expiry date returned by Twitch. Older inflated expiries can shorten when reconciled.

The transaction preserves active non-Twitch premium sources. Manual subscription checks and admin backfill now use this same API/reconciliation path. Backfill pages through linked profiles, reports errors as failures, and no longer stacks months or treats failed API calls as unsubscribed. Manual check response still provides `success`, `isLinked`, and `isSubscribed`; the unused optional tier is omitted. Source-wide lifecycle handling and renewal scheduling remain SX-015.

EventSub revocation records a receipt and emits an operational warning. Revocation concerns the event-delivery subscription; it does not revoke an end user's premium by itself.

## Rollout

1. Apply the reviewed migration manually using the project's migration procedure; do not run `supabase db push --linked`. Reconcile prior overextensions before accepting the new bounded-window policy in production.
2. Confirm `TWITCH_EVENTSUB_SECRET`, `TWITCH_BROADCASTER_ID`, `TWITCH_CLIENT_ID`, and a valid `TWITCH_BROADCASTER_TOKEN`. The token must belong to the broadcaster and have `channel:read:subscriptions`. An app access token is insufficient for the broadcaster lookup. Token renewal remains an operational/lifecycle prerequisite.
3. Deploy the webhook, manual subscription check, and admin backfill together. `config.toml` explicitly disables Supabase JWT verification for the webhook because Twitch HMAC authenticates it. The manual function still verifies Supabase identity; backfill retains the existing admin gate.
4. Verify real challenges, subscribe/end notifications, gifts, resubscription chat, duplicate delivery, stale signatures, and token failures using controlled accounts. Monitor callback latency and EventSub revocation warnings. Twitch can revoke delivery subscriptions after repeated slow/failing responses; this implementation performs the API check synchronously and needs a durable background inbox if measured latency warrants one.
5. Reconcile renewals regularly through the protected backfill/manual path. `channel.subscribe` excludes resubscriptions, and users need not send resubscription chat messages. No periodic job or token-refresh automation was deployed in this batch. Large backfills may need smaller scheduled batches to stay within function execution limits.

The migration retains minimal receipts and Twitch-ID observation state without raw payloads or names. It does not purge replay protection automatically. Account-link ownership still depends on the profile permissions audited in SX-001/SX-002; ambiguous multiple profile matches fail instead of choosing a user. The initial link-account flow, effective expiry enforcement everywhere, source fallback, and broader lifecycle cleanup remain SX-015.

## Validation

- 11 Deno tests pass: real HMAC verification/tampering, stale/future timestamps, broadcaster isolation, challenge response, gift-donor exclusion, duplicate shortcut, API failure handling, database failures, and exact subscriber matching.
- All three affected Edge entrypoints type-check.
- PostgreSQL 18 isolated tests pass for migration reapplication, fixed expiry under duplicate IDs and distinct IDs, inactive grace caps, older/tied observations, protection of Stripe access, conflicting receipt rejection, and client permission denial.
- Two independent simultaneous database connections produce exactly one receipt and one fixed expiry.
- Evidence: `implementation-10-deno-tests.txt`, `implementation-10-typecheck.txt`, and `implementation-10-postgres-tests.txt`.

Flutter and the sync worker were unchanged; their previously passing checks were not repeated. No real Twitch API requests were made during testing.
