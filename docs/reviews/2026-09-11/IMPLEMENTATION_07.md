# Batch 7 — Server-enforced guide credits

SX-011 is implemented locally. No migration, function, or client has been deployed. SX-003 also has local permission revocations, but its legacy-traffic and legitimate-purchase verification remain open.

## Behavior

- The guide endpoint verifies the bearer token with Supabase Auth; user IDs in submitted JSON cannot select the charged account. POST bodies are capped at 16,000 bytes, title/name at 300 characters each, description at 4,000, platform at 80, and request IDs must be UUIDs.
- A service-only PostgreSQL transaction locks the user row, reserves premium/pack/daily-free access in that order, and records the input hash and request ID. Expired premium does not grant unlimited access. Only one pending generation per user is allowed, including premium users.
- Completion saves the guide and settles the reservation in the same transaction before the client sees it. The same user/request/input returns the saved result; another input with that ID is rejected. Ambiguous commit failures return a retryable error without issuing a refund or starting generation again.
- Known provider failures, refusals, and empty responses release the reservation once. Pack refunds restore pack credits; daily refunds decrement the original reservation day's counter. Interrupted work expires after two minutes and is released lazily on the user's next generation request. A late completion cannot revive refunded work. A balance badge alone does not trigger recovery.
- Provider requests time out after 45 seconds; the client times out after 60. The existing GPT-4o-mini model and 300-token limit remain. Delivery is now one JSON result after settlement instead of partial SSE output. The app shows its loading indicator until the guide arrives. Response handling was checked against the [official Chat Completions reference](https://developers.openai.com/api/reference/resources/chat).
- Client request IDs survive reopening/restarting through shared preferences. The first ID derives from user/content, deduplicating the same first request across tabs/devices; subsequent attempts get a persisted random ID only after a confirmed release. A confirmed failure takes another explicit Retry to start generation. Account IDs are part of the identity key.
- Cached achievement guides open without spending credits, even with an empty balance. Actual server quota rejection retains the purchase dialog. Removed unused client consume/grant helpers. The server remains authoritative even if a caller bypasses this UI.

## Database and rollout

Migration: `supabase/migrations/20260911160000_ai_guide_reservations.sql`. New functions: `reserve_ai_guide`, `finish_ai_guide`. Request rows have RLS with no client access and an auth-user cascade on account deletion. `can_use_ai` now reads the actual `usage_date`/`uses_today` schema and matches premium expiry/source order. Existing same-day counters are preserved conservatively; new pack/premium uses do not consume the daily-free allowance.

The migration revokes client mutations (including TRUNCATE) on premium status, credit balances and usage, and execution of legacy add/consume RPCs. This intentionally ends the July legacy purchase compatibility grants. Current verified store/webhook fulfillment remains the supported purchase route. Service-role fulfillment permissions from the existing secure-store migration must already be present.

Before release:

1. Reconcile live schema/permissions and SX-003 legacy-client traffic. Verify the secure-store migration/fulfillment functions and real purchase/restore flows. Existing production metadata connection limitations from earlier batches remain unresolved.
2. Coordinate supported app version rollout. Old apps charge through the retired RPC and send no request ID; they will fail closed. Do not deploy the new function without its migration or assume old clients work during this change.
3. Apply the reviewed SQL manually under the project's migration procedure, then deploy the guide function and new Flutter client together. Do not run `supabase db push --linked`.
4. Verify direct unauthenticated and creditless calls, concurrency, lost responses, provider failure/refund, expiry recovery, premium expiry, and legitimate verified purchases in staging/live with controlled accounts. Monitor pending age and failures without logging credentials or provider response bodies.

Request IDs/input hashes/results are retained to prevent historical retries charging again. There is no automatic retention purge: deleting request rows would remove idempotency protection. Future output retention should preserve request tombstones. Client preference entries likewise have no automatic eviction. Shared achievement-guide cache quality/writability remains SX-035; YouTube/moderation quotas remain SX-012. This does not claim a global provider-spend rate limit.

## Validation

- 12 Deno handler tests: identity, method/input bounds, creditless/pending/replayed requests, ordering, provider failures, ambiguous settlement, and failed refund. Edge entrypoint type check passed.
- PostgreSQL 18 isolated database: migration reapplication, source selection, daily exhaustion, premium expiry, replay/conflict, single refunds, crash expiry/late completion, and permission assertions passed. Concurrent independent connections competed for one pack credit; exactly one reserved, duplicates did not charge, and repeated refund restored one credit.
- Full Flutter suite: 69 passed, 9 web-only skipped. An additional persisted-reopen regression was added afterward; all four focused guide-client tests pass. Static analysis clean.
- Release web build passed. Existing optional Wasm dry-run incompatibility warnings remain; the JavaScript build completed successfully.
- Validation output: `implementation-07-deno-tests.txt`, `implementation-07-postgres-tests.txt`, `implementation-07-flutter-tests.txt`, `implementation-07-client-tests.txt`, `implementation-07-analysis.txt`, `implementation-07-web-build.txt`.

No real OpenAI calls, purchased-credit changes, or live account mutations were used in tests.
