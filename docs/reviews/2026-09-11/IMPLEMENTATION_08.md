# Batch 8 — Provider quotas and sync admission

SX-012 is implemented locally; deployment and controlled live verification remain pending. No provider calls, live migrations, or account mutations were made during validation.

## Enforcement

`20260911180000_provider_quotas.sql` adds service-only policy/counter tables and the atomic `admit_provider_request` RPC. A short per-provider row lock serializes global and user admission checks across instances. Counters use UTC days and cooldown timestamps cross midnight. Active premium requires an unexpired entitlement. Clients cannot modify counters, policy, or call the admission RPC directly.

| Operation | Free daily attempts | Premium daily attempts | Shared daily ceiling | Free / premium cooldown |
| --- | ---: | ---: | ---: | --- |
| YouTube search | 10 | 30 | 90 | 3 / 3 seconds |
| Moderation | 100 | 200 | 5,000 | 1 / 1 seconds |
| New AI generation | 100 | 100 | 1,000 | 5 / 5 seconds |
| PSN sync start | 3 | 12 | 10,000 | 120 / 30 minutes |
| Xbox sync start | 24 | 96 | 10,000 | 60 / 15 minutes |
| Steam sync start | 24 | 96 | 10,000 | 60 / 15 minutes |

These are conservative **application defaults**, not measured provider allowances. Review actual upstream quotas, expected traffic, and operational budget before release, especially the YouTube shared ceiling. Trusted operators can adjust policy rows; migration reapplication preserves adjusted values. Keep published premium limits aligned with policy changes.

AI still requires the separate SX-011 credit reservation: free users get three successful new guides per day, pack users spend purchased credits, and premium guides do not spend pack credits. The 100-attempt ceiling bounds retries/provider failures and premium usage; it does not grant 100 free guides. Saved-guide replays use neither admission nor another credit. If admission fails after credit reservation, the server confirms release before returning a retry response. Client retries recognize confirmed release on 429/503 as well as generation failure. Premium copy now discloses daily limits and the comparison shows 100/day.

YouTube and moderation verify identity through Supabase Auth before parsing bounded bodies and reserving quota. Body size is capped at 24,000 bytes; YouTube queries at 500 characters and results at 1–5; moderation input at 5,000 characters. Both use 15-second provider timeouts, POST-only handling, CORS on errors, and sanitized failures. The moderation response contract was checked against the [official OpenAI Moderation reference](https://developers.openai.com/api/reference/resources/moderations/methods/create). A moderation outage is not reported as safe content.

## Sync policy

Manual sync, automatic sync, and force-resync requests share the same server policy. Client flags do not bypass admission. Each active Edge entrypoint checks linked/current-sync state, then reserves admission before provider token refresh, sync log changes, or Railway dispatch. The worker's recovery scans also reserve admission because each restarts an upstream scan. The existing shared-secret-protected Railway routes remain trusted internal dispatch routes; they do not charge a second admission for Edge-dispatched work.

Accepted attempts consume cooldown/daily capacity even if provider refresh, log creation, or dispatch later fails. This prevents failure/retry storms. Rejected admission does not increment counters. Limits return 429 and retry timing; an unavailable quota database returns 503 and no dispatch. The read-only `can_user_sync` UI check now reads this same policy/counter ledger and cannot inspect another user's state. Legacy client-written sync history no longer authorizes starts.

This does not replace SX-017 durable job ownership/leases or repair existing profile-based recovery selection. Recovery can be delayed by the same cooldown or daily limit. Initial rollout starts a fresh admission ledger; earlier historical syncs are not backfilled. Rows older than two previous UTC days are removed on successful admission for that provider; account deletion removes user counter rows and retains aggregate totals.

## Rollout

1. Complete live permission/schema reconciliation and retire self-granted premium entitlements using the previous batch's migration. Quotas trusting premium require those permissions to be closed.
2. Apply this reviewed migration manually using the repository migration procedure. Do not use `supabase db push --linked`. Confirm the service role can call the RPC and client roles cannot mutate policy/counters.
3. Deploy `youtube-search`, `moderate-content`, `generate-achievement-guide`, `psn-start-sync`, `xbox-start-sync`, and `steam-start-sync`, then the updated Railway worker and Flutter client. Missing migration fails closed.
4. Verify manual and automatic syncs, expired premium, provider outages, simultaneous starts, exhausted/shared limits, guide refunds/replays, and purchase behavior with controlled accounts. Review 429/503 rates and adjust ceilings from real usage. Do not restore insecure client grants to roll back a release.

## Local validation

- 19 Deno tests pass: identity/input guards, admission-before-provider execution, rejection/outage behavior, guide refund on quota denial, and replay without quota use. All six affected Edge entrypoints type-check.
- PostgreSQL 18 isolated tests pass for cooldowns, premium expiry, daily/global limits, non-consuming UI checks, permissions, account cleanup, and migration reapplication. Two independent concurrent users competing for one shared slot admit exactly one.
- 17 worker tests pass, including recovery admission failing closed. Worker syntax check passes.
- Full Flutter suite: 70 passed, 9 web-only skipped; analysis clean. Expanded client regression tests cover confirmed releases at 422, 429, and 503.
- All six focused client tests and the release web build pass. Existing optional Wasm dry-run warnings remain; the JavaScript release build succeeds.
- Evidence is saved alongside this document as `implementation-08-*-tests.txt`, `implementation-08-analysis.txt`, and `implementation-08-web-build.txt`.
