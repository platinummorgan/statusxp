# Xbox Mythic Scoring Release

Released November 15, 2026. The database, Railway sync service, and production web app now support Xbox Mythics. Counts and completion XP populate during normal user syncs. No user sync or historical backfill was initiated for this release. Native mobile installations need a client release for the interface changes.

## Released behavior

- Native `titles[].achievement.isMythic` confirms each award. Achievement percentage or Gamerscore never creates a Mythic.
- Modern achievement requests use contract 6. Completion metadata survives pagination. Original `BaseGame` membership selects required IDs; DLC and later additions outside that group do not affect the estimate.
- Estimated rarity is the lowest required achievement percentage. All required definitions and valid rarity values must be present; zero is valid. Unknown membership or rarity stays unknown rather than using the minimum of a potentially incomplete set.
- Each earned award contributes `round(0.5 + 11.5 * 5 * (1 - estimated_rarity / 100)^3, 2)` once alongside ordinary achievement XP. Missing rarity uses the existing 0.50 XP default until a verified estimate arrives. A 1% estimate yields 56.29 XP. A zero estimate yields 58.00 XP.
- Confirmed native Mythics survive incomplete or false later responses. Xbox 360/native legacy awards are retained even when modern groups are unavailable. Unknown completion dates remain null.
- Old and new scores are combined before the existing per-game integer rounding. Mythics do not inflate ordinary achievement counts or native Gamerscore.

## Database and contracts

[Core migration](../../../supabase/migrations/_manual_production_archive/20261115200000_xbox_mythic_completion.sql), [potential-owner refresh migration](../../../supabase/migrations/_manual_production_archive/20261115203000_refresh_mythic_potential_owners.sql), and [dashboard/library game totals migration](../../../supabase/migrations/_manual_production_archive/20261115204500_include_mythics_in_game_totals.sql).

| Object | Purpose |
| --- | --- |
| `xbox_mythic_catalog` | Original membership IDs, membership revision, verified estimate, source, generated 5x completion XP |
| `user_xbox_mythics` | One native award per user and Xbox title, provider identity, nullable real completion time |
| `xbox_mythic_sync_state` | Marks a completed Mythic-aware sync for the linked identity |
| `xbox_mythic_awards` | Visible award projection without provider identities |
| `statusxp_score_events` | Ordinary achievement and completion points consumed by scoring and seasonal queries |
| `statusxp_possible_game_points` | Catalog potential points including known completion awards |
| `get_xbox_mythic_stats` | Nullable count plus explicit known/unknown sync state |
| `get_xbox_mythic_leaderboard` | All-time Mythic ranking and movement |
| `get_xbox_mythic_period_leaderboard` | Weekly/monthly Mythic gains based on genuine completion dates |
| `xbox_mythic_leaderboard_history` | New metric history, separate from old Gamerscore ranks |

Only the service role can record awards or mark sync state. Both operations validate the linked XUID and tracked active sync job. Clients cannot grant themselves awards or read provider identities. Catalog estimates are publicly readable; catalog writes and truncation are denied to client roles. Award visibility respects public profile settings, owner access, and merged account status.

Native awards are keyed by Xbox title to prevent duplicate completion counts under different Xbox platform IDs. Linked identity checks prevent a disconnected or changed account from contributing another identity's awards. Reconnection to the original identity restores its retained records. Durable refresh jobs cover new awards, catalog additions and rarity changes affecting all owners' potential scores, and account identity changes; unchanged confirmations do not add refresh jobs.

The full and per-user StatusXP refresh paths use the same event stream. Dashboard and library game totals, including the public library wrapper, include Mythic awards before per-game rounding. Focused SQL assertions verify both game readers return the same 72 XP fixture total as the canonical scorer. Potential totals include catalog completion awards without requiring an earned completion. Seasonal StatusXP, game breakdowns, and Hall of Fame include dated completion points. Xbox seasonal boards and their breakdowns count Mythics; undated imports count only all-time. The scheduled Xbox snapshot now additionally records Mythic ranks. Existing Gamerscore APIs/history remain available to older app installations.

## Interface

The mobile-layout and desktop web dashboards show Xbox Mythics. Before a successful Mythic-aware sync, the count is unknown and the dashboard prompts `Sync Xbox`; it does not substitute Gamerscore or claim a confirmed zero.

The Xbox leaderboard orders by Mythic count descending, ordinary achievement count descending, then user ID for stable ties. Only accounts with a completed Mythic-aware sync appear. An empty board explains that rankings populate as players sync. A verified zero can appear once the account has synced. Rank movement uses the new Mythic history exclusively.

The game achievement screen displays an earned Mythic card with its completion XP and `Estimated rarity`, or states that rarity is pending. Ordinary achievement rows and their native Gamerscore remain intact. Weekly/monthly leaderboard labels and game breakdowns use Mythics.

## Verification

- 95 sync-service tests passed, including six new Mythic tests covering original-only rarity, missing/zero values, genuine dates, pagination metadata, incremental processing, native confirmation, and storage failures.
- 16 Flutter dashboard/repository/widget tests passed. They cover unknown, zero, positive, and cached Mythic states; new leaderboard metrics/APIs; estimated-rarity labels; and existing dashboard pagination/startup/retry behavior.
- Targeted Dart analysis found no issues. The production Flutter web build passed.
- PlayStation and Xbox database assertions passed together inside a transaction that rolled back. Checks cover 5x award storage, once-per-title scoring, ordinary counts, full/per-user potential and earned totals, legacy undated awards, seasonal reconciliation, identity protection, catalog refreshes for owners without a Mythic, dashboard/library game totals, and client permissions.
- Post-migration verification covered 101 existing leaderboard users: zero score changes, zero discrepancies against canonical earned/potential/game totals, and no persistent test users or games. All Mythic tables started empty, as expected before user sync. [Sanitized result](xbox-mythic-release-verification.json)
- Public production API requests returned 200 for new read APIs and the canonical calculator. Direct provider-identity reads were denied. The deployed JavaScript hash matches the local production build; the home page, leaderboard route, login callback and asset-links route returned 200.

Railway deployment: `b7ae97ba-8852-4998-acff-e63bd6fded2d`, status `SUCCESS`, health endpoint 200. This deploy also includes the locally prepared PlayStation sync helper with its confirmed 5x rule. Production web is aliased to [statusxp.com](https://statusxp.com).

## Follow-up

November 16 update: [the first positive live account](../2026-11-16/XBOX_POSITIVE_MYTHIC_SYNC_CHECK.md) confirmed seven Mythics, correct leaderboard/dashboard counts, three verified rarity bonuses and a matching canonical/cached account score. Four legacy titles correctly remain rarity-pending at the existing 0.50 XP floor. The remaining follow-up is native legacy membership/rarity coverage and a live partial-DLC example.

Observe the first user-initiated Xbox syncs for real-world completion coverage and unavailable legacy rarity. The earlier live payload verification establishes source shapes; this release did not automatically sync accounts. The displayed count comes from confirmed per-title records after a complete sync, rather than assuming an account-summary total can be scored without title identities. Account-summary discrepancies and inaccessible titles remain coverage-review work.

OpenXBL completion-group forwarding remains unverified. Direct contract 6 supplies the authoritative modern membership; provider/legacy fallbacks retain ordinary unlock support and native title-history Mythics without inventing base-game membership.

Steam completion storage and eligibility are still pending. Use the same selected 5x rarity-component rule when that work is released.

Return to the [completion implementation plan](../../development/COMPLETION_RARITY_SCORING_PLAN.md).
