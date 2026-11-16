# Steam Completions release

Released November 15, 2026 to the database, Railway sync service and production web at [statusxp.com](https://statusxp.com). Native mobile installations need a client release for the interface updates. Steam records populate on normal user syncs; no user sync or historical earned-completion backfill was initiated by this release.

## Names and counts

The dashboard shows **Platinums**, **Xbox Mythics**, and **Steam Completions**, plus **Total Completions**, their sum. Each platform accomplishment counts separately. Steam uses the earned badge **Base Game 100%**. Tooltips explain that all required day-one base-game achievements count, including Steam-exclusive originals, while DLC and later additions are excluded.

An unsynced account has an unknown completion count and a Sync Steam prompt. After a successful completion-aware sync, the count includes only reviewed completions; the dashboard visibly reports games pending review. Total Completions says verified so far when counts or membership coverage are incomplete. The number animation preserves unknown values rather than rendering a false zero.

Steam all-time and weekly/monthly leaderboards now use completion count, with ordinary achievement count as the all-time tie-breaker and user ID for stable ordering. Separate completion rank history prevents comparisons against old achievement-count ranks. Existing achievement-count APIs and history remain available for older clients. Seasonal game breakdowns and Hall of Fame use completion counts too.

## Initial membership coverage

| Game | AppID | Required day-one base set | Excluded add-on achievements |
| --- | --- | --- | --- |
| The Witcher 3 | 292030 | 52 | 26 |
| Cyberpunk 2077 | 1091500 | 44 | 13 |

These two lists have exhaustive unique mappings to verified PlayStation base/add-on groups for the corresponding games. The review records stable Steam API IDs, reference trophy IDs, grouping evidence, version differences and all exclusions. Actual qualification always uses Steam's native unlocks rather than substituting PlayStation requirements. Cyberpunk's Legendary/Tier 5 wording difference is explained by [CDPR's Update 2.0 terminology change](https://www.cyberpunk.net/en/news/49060/update-2-0).

**Other games are pending review and do not yet award Steam Completions.** Default Steam group membership is not automatically approved as original-only. Portal 2's extra Talent Show achievement still needs release-timing evidence. [Catalog and expansion workflow](../../development/steam-completion-catalog/README.md)

## Calculation and storage

The reviewed catalog stores original required IDs separately from exclusions and current observed IDs, with review state, membership revision and evidence. Client roles cannot approve reviews. The service-only review RPC requires a nonempty exhaustive classification; the local review command defaults to a dry run. Manual classifications survive normal syncs.

Normal sync records current native achievement states after definitions and unlocks are saved. All required achievements must be earned, including original Steam exclusives. Rounded percentage, an empty set, and stale stored unlocks cannot grant an award. A corrected membership revision requires re-evaluation. Removing a required definition marks the game needs_review. New IDs appearing after an exhaustive verified snapshot are excluded as later additions.

The estimated rarity is the minimum percentage across that same required set, with every required rarity present. Valid zero values are retained. The completion award is `round(0.5 + 11.5 * 5 * (1 - estimated_rarity / 100)^3, 2)`, with the existing 0.50 XP default when rarity is unavailable. The game card explicitly labels estimated or unavailable rarity. Ordinary achievements retain their formula and continue to earn XP, including DLC.

A completion contributes once per user/AppID. Completion dates use the latest required native unlock timestamp only when every required date is valid. Unknown dates stay null and count all-time only. The current native Steam state determines eligibility; a reset or incomplete required achievement can remove current completion eligibility even if an older individual unlock remains stored.

The shared completion event stream now includes Xbox and Steam awards. Canonical, full/per-user leaderboard refresh, potential points, dashboard/library game totals, seasonal StatusXP, breakdowns and Hall of Fame consume consistent sources. Awards are added before the existing per-game rounding. Durable jobs refresh all affected owners when catalog points, review state, membership revision or linked identity changes.

The playtime optimization checks completion review state/revision and uses a separate completion-check timestamp. A new/revised review bypasses the recent-playtime skip, and repeated fast skips do not postpone completion rechecks forever.

## Applied migrations

- [Storage, normal sync contracts, shared scoring, leaderboard and seasonal integration](../../../supabase/migrations/_manual_production_archive/20261115213000_steam_completions.sql)
- [Two initial reviewed sets and atomic potential-score refresh](../../../supabase/migrations/_manual_production_archive/20261115214500_review_initial_steam_completion_sets.sql)

Raw progress and account identities are private. Service writes validate the linked Steam identity and the tracked active sync job. Public read projections respect profile visibility and omit provider identity fields.

## Validation and deployment

- 98 sync-service tests passed, including native state validation and storage-failure handling.
- 22 Flutter tests passed, covering completion counts, unknown/zero states, coverage notes, combined totals, new leaderboard metrics, badges, existing dashboard pagination/startup/retry behavior and preservation of unknown values in the real dashboard animation.
- Targeted Dart analysis found no issues; the production web build passed.
- PlayStation, Xbox and Steam SQL assertions passed together in a rolled-back production rehearsal. Steam cases cover pending reviews, day-one Steam exclusives, locked rarer DLC exclusion, duplicate-safe awards, zero rarity, stale stored unlocks, unknown dates, seasonal breakdowns, dashboard/library rounding, earned/potential/full/per-user agreement and client permissions.
- Production verification covered 101 leaderboard players: zero earned-score changes, five potential-score changes totaling 372 additional potential XP, zero canonical-cache discrepancies, and no persistent fixture users or games. Steam progress and sync-state tables began empty. [Database result](steam-completion-release-verification.json)
- Public completion APIs and the canonical calculator returned 200; two reviewed sets are readable, and private identity reads are denied. [API result](steam-completion-api-verification.json)
- The deployed web JavaScript hash matches the release build. Home, leaderboard, login callback and asset-links routes returned 200.

Railway deployment `cdeb3338-db21-4dd9-b995-704972adbd7e` is SUCCESS and its health endpoint returns 200. Production web deployment `statusxp-4scdxmvsk-michaels-projects-4c786e88.vercel.app` is aliased to statusxp.com.

## Operational follow-up and recovery

Observe the first normal Steam syncs and expand reviewed membership coverage using the checked-in catalog workflow. Additional games can be reviewed without a client release. Native app releases remain pending. Profile/library completion badges beyond the earned game screen and a complete interactive score-breakdown page remain separate interface work.

If a catalog classification is wrong, set it to needs_review, retain its evidence and revision, and drain affected StatusXP refresh jobs. Fix the reviewed set and let normal sync re-evaluate users. Do not delete user achievements or fabricate completion dates.

A release rollback should restore the prior Railway/web deployments and the saved pre-release shared function/view definitions, then refresh earned and potential caches. Preserve completion tables and review evidence. The prior Xbox release is recorded in [Xbox release notes](XBOX_MYTHIC_SCORING_RELEASE.md); source-definition and cache backups were captured privately before this release.

Return to the [implementation plan](../../development/COMPLETION_RARITY_SCORING_PLAN.md).

## Subsequent Steam-only coverage

The [Playrooms review](PLAYROOMS_COMPLETION_REVIEW.md) adds a third verified title with 30 required original achievements. A normal native-phone sync produced one real Steam completion and a reconciled score increase. Steam-only membership can be established from Steam/developer evidence without a console reference.
