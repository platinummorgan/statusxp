# Native Steam completion sets

November 16, 2026. Implements the [read-only proof of concept](STEAM_ACHIEVEMENT_SETS_POC.md). Steam no longer requires manual launch-date research or PlayStation/Xbox achievement matching for completion eligibility.

## Current rule

Use a validated native Steam base-game set when it can be separated reliably. Otherwise require **all available Steam achievements**. Keep Steam-exclusive achievements in the selected set. Explicitly archived achievements/groups and unavailable developer-only groups are excluded only when complete, valid native metadata establishes them. Spoiler achievements remain required. An empty set awards nothing.

The conservative policy established by the proof remains: a populated built-in base group plus DLC-restricted custom groups is accepted; a default undivided list, absent populated base group, incomplete ID join, unrecognized metadata, or additional unrestricted custom groups uses the full-set fallback. Do not guess whether unrestricted mode/event/update groups are original content. This is StatusXP's full-base policy, not a claim that Valve lacks a literal built-in base set in those games.

Every required achievement must be natively earned. Count **once per user/AppID**, not once per group. The exact same required IDs determine estimated rarity:

```text
estimated rarity = minimum global unlock percentage across required IDs
Steam completion XP = round(0.5 + 11.5 × (1 − estimated rarity / 100)^3, 2)
```

Steam now uses **1×** on the rarity component. PlayStation and Xbox remain at their existing 5×. Valid zero rarity gives 12 XP. Missing rarity stays null and explicitly unavailable; production retains its existing 0.50 XP fallback for compatibility with older clients. The proof's local hypothetical evaluator left unavailable XP null; the deployed award contract preserves the existing numeric floor.

Ordinary achievements, including DLC achievements, continue earning ordinary XP independently of whether they are required for the completion award.

## Implementation

- `sync-service/steam-achievement-sets.js` owns selection, shared caching, optimistic concurrent-update protection, and the bounded background refresher. The experimental collector imports the same selector rather than maintaining a competing implementation.
- Public `schema_v2` JSON is joined by `api_name` to the native Web API IDs. Every ID, metadata flag, group reference, and exhaustive schema join must validate before a subset can be accepted. Unknown or partially joined archival data never silently removes a requirement.
- Cache each AppID globally for seven days; provider errors, unrecognized metadata and schema mismatches retry after thirty minutes. Concurrent normal syncs in one service instance share a pending request. Background refresh handles three due games per minute. Database comparisons reject results based on an outdated observed schema; another service instance may repeat a request, but cannot overwrite a newer schema with that old snapshot.
- A page outage or parser failure preserves an existing usable native set. A new/changed native schema without usable grouping gets the full-set fallback. Database read/write errors still fail the affected import instead of pretending completion was saved.
- Normal sync resolves membership before recording actual native unlock state, on both processing paths. Metadata version 2 forces existing records through the new logic. A signature of the full sorted API-ID list forces definition import even when the total achievement count is unchanged. The recent-playtime optimization also checks policy version, revision and refresh expiry.
- Additive catalog fields record policy, version and refresh timestamps. Existing private snapshots preserve previous manual classifications and every newly selected requirement/evidence version. Provider-account identities remain private.
- `apply_steam_completion_policy` is service-only, verifies stored native IDs, validates exhaustive required/excluded membership, and computes rarity over the selected requirements. The existing awards, game totals, leaderboard, seasonal and potential-point sources consume the updated catalog. The generated Steam point expression changes in place, retaining dependent views.
- The previous console/day-one background worker is no longer started, its claim RPC returns no work, and its manual approval RPC rejects obsolete scope changes. Historical review jobs and JSON classifications remain as audit records. Do not run the old manual approval CLI to change current requirements.

## Transition and historical completions

Existing stored definitions seed the full-set fallback immediately; background refresh discovers official separation. Initialization creates no player unlocks or progress. Catalog changes queue score refreshes once per affected owner during the bulk transition; later updates use the existing durable refresh triggers.

Qualification follows **current native requirements**, rather than grandfathering the old day-one/console-based award. A changed requirement revision stops an older completion from appearing until a normal Steam sync checks the new set. No account sync is automatically launched by this release, and Steam's historical retained set-completion flag is not inferred from old unlock records.

For the investigated account, Rust's current fallback is 116 requirements and the last read-only native check earned 55: the old 48/48 day-one completion no longer qualifies. Slender requires all 21, including the Steam-exclusive achievement, rather than the previous 20 console equivalents. Playrooms remains 30 and The Room remains 5. Other newly qualifying games become known through normal Steam sync.

The standard API may contain newer IDs than the stored catalog. Normal sync imports them before evaluating completion. The background worker cannot invent missing native definitions or native earned state from a public achievement page.

## Interface and client compatibility

The dashboard keeps **Steam Completions** and the unified **Total Completions**. Its explanation now describes native base requirements with the full-set fallback. Coverage awaiting a fresh native check says “Awaiting sync,” replacing manual-review wording.

The earned badge says **Base Game 100%** for an accepted official subset and **All Achievements 100%** for the fallback. Its estimate explanation says 1× weighting. Policy is derived from the award's existing `rarity_source` field, so the public award projection does not gain a breaking column contract. Existing sync and dashboard RPC signatures remain compatible. Older mobile apps continue syncing, but retain old explanatory text/badges until a client update.

The connected-phone acceptance pass found and fixed a missing badge on the canonical `GameOverviewScreen` route, which is separate from the older achievement screen. The corrected test APK is installed on the phone, and the same fix is deployed to production web at `statusxp-qmls0ezez-michaels-projects-4c786e88.vercel.app`. See [phone results and regression checks](ANDROID_NATIVE_STEAM_PHONE_CHECK.md). The store mobile release remains pending.

## Validation

- 137 sync-service tests passed, including the shared selector, DLC/Steam-exclusive handling, archives/spoilers, absent/ambiguous groups, cache hits, outage preservation, retry behavior, concurrency, same-count definition changes, native-state validation and one-game counting.
- 22 targeted Flutter tests passed for Steam/Xbox summaries, unknown/zero states, coverage, fallback badges, estimated rarity, startup/cache behavior and dashboard pagination. Targeted analysis found no issues.
- Production web release build passed. The toolchain reports existing WebAssembly compatibility warnings; the JavaScript web build succeeds.
- The migration and SQL assertions passed in a rolled-back linked-database rehearsal. Checks cover 1× points, same-set rarity, zero/missing rarity, no fabricated dates/unlocks, changed revisions, native Steam-exclusive requirements, locked DLC, duplicate-safe awards, canonical/dashboard/cached totals, potential points, empty sets, stale-worker rejection and client-role restrictions.
- Post-release verification covered **101 leaderboard players**, with **zero earned-score cache mismatches** and **zero potential-score cache mismatches**. All 1,400 tracked Steam games have the native policy enabled, and no Steam/PlayStation/Xbox weighting discrepancies were found. No SQL fixture account remains.

## Deployment and observed state

- Database migration applied successfully and archived exactly under `_manual_production_archive`. Initial native requirements cover 1,400 tracked games. Warm-up refreshed 67 priority games without errors: two accepted official base subsets and 65 full-set fallbacks. Remaining grouping refreshes continue in the background; a full-set fallback is already usable before that refresh.
- Railway deployment **ff01e8c6-1488-4f4b-ac76-899de7baa25a** reports SUCCESS and passed its `/health` check on Node 20.20.2. The isolated runtime stage contains 29 modules and no credential files. The first attempt, `2ea404d5-be8b-4b43-aed8-56e28cf0024a`, failed because ignore rules omitted its lockfile; the corrected upload explicitly includes the validated lockfile. The running service remained healthy during that failed build.
- A later observation counted 79 refreshed games and 1,321 awaiting background refresh, confirming the new worker continues beyond the initial 67-game warm-up. The deployed runtime files match the validated local source.
- Production web deployment **statusxp-62g9y45fm-michaels-projects-4c786e88.vercel.app** is aliased to **statusxp.com**. Home, login callback, asset-links and main JavaScript return HTTP 200; the published JavaScript SHA-256 matches the local release build.
- The investigated account currently has **two Steam completions** (Playrooms and The Room) and **13 changed games awaiting a normal Steam completion sync**. Rust's earlier day-one completion is no longer eligible. No user sync was triggered and no player unlock state was fabricated.
- [Sanitized deployment verification](native-steam-release-verification.json) records rollout, score reconciliation, weights, warm-up and web checks.

## Files and operations

Migration: `supabase/migrations/_manual_production_archive/20261116190000_native_steam_completion_sets.sql` after application. SQL regression: `supabase/tests/native_steam_completion_sets.sql`. The regression runs inside a transaction and rolls back its fixture account/game.

The previous day-one scoring and manual-review SQL tests moved to `supabase/tests/_historical/steam-day-one-20261115/`, because their original expectations deliberately conflict with the new policy. The current native regression replaces them.

No new provider credentials or environment variables are required. Refresh failures retain requirements and use the retry timestamp; they do not resurrect console matching. Public-page format changes should be handled in the adapter/parser and tested against captured public fixtures. Initial failure fallback is intentionally stricter than a previously reviewed DLC-free set.

Before release, prior catalog/progress and replaced RPC definitions were saved under ignored `.railway-upload/native-steam-before.json`; the full migration/test rehearsal is also retained privately. Preserve evidence and native progress when correcting a policy. Reverting to the earlier scoring policy would require restoring prior requirements and scoring definitions and refreshing affected totals, not deleting earned achievements.
