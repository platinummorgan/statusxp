# StatusXP Completion Rarity Implementation Plan

## Current Steam rule — November 16, 2026

Steam uses a verified native base-game set, otherwise all available achievements. No console matching or day-one mapping is required. Steam-exclusive achievements remain included. Qualification and estimated minimum rarity use the same IDs; each AppID counts once. Steam uses 1× rarity weighting, while PlayStation/Xbox remain at 5×. Normal sync confirms changed requirements; prior day-one completions are not grandfathered. Shared cached grouping replaces the manual review queue. See the [native Steam implementation and release record](../reviews/2026-11-16/NATIVE_STEAM_COMPLETION_SETS_RELEASE.md).

## Historical plan

The Steam day-one/console-equivalent membership, 5× Steam weighting and manual-review instructions below describe the earlier implementation and are superseded by the current rule above.


Updated November 16, 2026. PlayStation native Platinum scoring is live with the confirmed 5x rarity-component weight. Xbox Mythic sync, storage, scoring, dashboard counts, and all-time/seasonal leaderboard changes are live in the backend and web app. Counts populate as users sync; Steam completion scoring and reviewed membership are also live. Native store releases and further Steam catalog coverage remain pending. [Xbox release](../reviews/2026-11-15/XBOX_MYTHIC_SCORING_RELEASE.md). See the [PlayStation release](../reviews/2026-11-15/PSN_PLATINUM_SCORING_RELEASE.md), [source verification report](../reviews/2026-11-14/COMPLETION_DATA_VERIFICATION.md), and [sanitized samples](../reviews/2026-11-14/completion-data-samples.json).

StatusXP will count the rarity of earned PlayStation Platinums, Xbox Mythics, and Steam 100% equivalents in its score. Xbox support includes original-achievement progress and historical Mythic unlocks. Deliver this through small changes that collect data, compare candidate scores, and then activate the chosen scoring rules across all platforms.

The user clarified that the intended completion feature includes an additional rarity-based bonus to give rare completions stronger recognition against large collections of high-unlock-rate completions. The initial PlayStation 1x release established included native rarity points. The user has now confirmed 5x on the rarity component for Platinums, Mythics, and Steam base-game 100%, retaining the 0.5 XP floor. Ordinary achievements retain their existing formula. The supplied earlier discussion contains illustrative preview totals and no fixed bonus equation. [Bonus proposal and previews](../reviews/2026-11-15/PLATINUM_COMPLETION_BONUS_PROPOSAL.md)

Use this checklist as the ongoing implementation record. Update completed tasks with the relevant commit, migration, or verification result, and record resolved decisions in the decision table.

## Confirmed scope

| Platform | Completion milestone | Required scoring input |
| --- | --- | --- |
| PlayStation | Earned Platinum trophy | Platinum rarity and confirmed unlock |
| Xbox | Earned Mythic | Confirmed Mythic unlock and the lowest required base-game achievement rarity as a provisional estimate |
| Steam | All reviewed base-completion requirements earned. A verified console counterpart can define the equivalent regular trophy set, excluding Steam-only extras and DLC. Games without a counterpart use their reviewed original Steam set. | Lowest rarity percentage among those required achievements as a completion rarity estimate, with confirmed completion |

Steam completion eligibility and completion rarity use the same base-game achievement set. Every achievement in that set must be unlocked. Use the lowest rarity percentage among those achievements as the completion rarity estimate. DLC achievements are excluded from both the unlock check and rarity selection. For example, base-game rarities of 10%, 20%, and 30% produce a completion rarity input of 10%. This is an upper bound on the actual completion percentage when the achievement rates share the same player population, and must be presented as an estimate.

For Early Access games, the user confirmed that the full 1.0 release is the day-one cutoff; achievements already present during Early Access remain required. For games with no achievements at full release, the user confirmed that the first official achievement set becomes the base set. Exclude subsequent additions and record the exception and introduction date in catalog evidence.

The user updated the Steam rule on November 16. Where a verified console counterpart defines the base completion, earning its equivalent regular trophy requirements qualifies Steam. The console Platinum itself and Steam-only extras are excluded. Slender uses 20 regular PS5 trophy equivalents and excludes I Escaped?. A Steam-only game without a verified console counterpart continues to use its reviewed original Steam set. Apply the chosen required set to both eligibility and estimated rarity, and record its scope explicitly.

Xbox and Steam completion scores use the lowest percentage among required base-game achievements as their estimated rarity input to the StatusXP formula. Label the percentage `Estimated rarity` in the interface and identify its estimated source in completion score explanations. Exclude DLC and the completion award itself from the minimum. PlayStation continues to use native Platinum rarity. The confirmed completion formula is `round(0.5 + 11.5 * 5 * (1 - rarity_percent / 100)^3, 2)`. Missing rarity currently defaults to 0.5 XP for PlayStation; Xbox and Steam use the same 0.50 XP default for unavailable completion rarity, with explicit unavailable labels.

Xbox awards Mythics for original achievements, excludes achievements added through DLC and updates, and retains earned Mythic status. Historical completions, including eligible Xbox 360 games, receive Mythics. These rules govern Xbox completion eligibility. [Xbox announcement](https://news.xbox.com/en-us/2026/09/29/xbox-insiders-october-2026-console-features-4/)

## Current implementation

- Production PSN Platinum definitions now use native rarity and the 5x rarity-component award stored once in `base_status_xp`, with included scoring and `rarity_multiplier = 1`. All 9,698 existing definitions were backfilled, and global earned and potential scores were refreshed. The sync source is now deployed on Railway, and the database trigger also supports legacy sync flags. [PlayStation release](../reviews/2026-11-15/PSN_PLATINUM_SCORING_RELEASE.md)
- Xbox sync uses native title-history Mythic status and contract-6 original BaseGame membership. Completion awards are stored separately from ordinary achievements, use estimated minimum rarity and the selected 5x component, and contribute to earned and potential StatusXP. The dashboard and new Xbox all-time/seasonal APIs use Mythic counts. Native mobile UI rollout and first user-sync coverage observation remain pending. [Xbox release](../reviews/2026-11-15/XBOX_MYTHIC_SCORING_RELEASE.md)
- Steam sync computes reviewed original-base completion from current native unlocks, uses minimum required rarity, and records one 5x award per AppID. The catalog has 34 reviewed games, including 31 approved from the original 34-game pending batch. Three games remain under review. The deployed worker collects schemas, official release evidence and console mappings automatically, and can reuse an identical previously reviewed Steam set. The dashboard displays Steam Completions and the platform sum Total Completions. [Steam release](../reviews/2026-11-15/STEAM_COMPLETIONS_RELEASE.md), [catalog review workflow](steam-completion-catalog/README.md)
- Full leaderboard refresh sums eligible achievement scores. Per-user refresh uses `calculate_statusxp_with_stacks`. Full and per-user paths now share ordinary and Xbox completion score events and potential points; database regression checks confirm agreement. Steam awards now use that shared source too, including game totals and seasonal scoring. [Leaderboard refresh](../../supabase/migrations/20261013130000_repair_full_statusxp_refresh.sql)
- Game overview reads ordinary progress and catalog metadata. Completion status and rarity need to reach its model and repository. [Game model](../../lib/domain/game_overview.dart), [Game repository](../../lib/data/repositories/game_overview_repository.dart)

## Decisions to settle

The user has established that all three completion types contribute rarity-based StatusXP. Steam uses all base-game achievements for eligibility and their lowest rarity as the scoring estimate. The table records confirmed rules alongside remaining implementation choices.

| Decision | What needs to be settled | Status |
| --- | --- | --- |
| Completion weight | Use 5x on the rarity component only: `round(0.5 + 11.5 * 5 * (1 - rarity / 100)^3, 2)`. Keep the 0.5 XP floor, ordinary achievement scoring, and one contribution per completion. | Confirmed by user |
| Xbox rarity | Use the lowest rarity among required base-game achievements as a provisional estimate. Adopt a verified native Mythic rarity source when one becomes accessible through the integration. | Confirmed by user |
| Steam rarity | Lowest base-game achievement rarity percentage, excluding DLC, used as a completion rarity estimate. | Confirmed by user |
| Estimated rarity display | Label Xbox and Steam minimum-percentage completion rarity as `Estimated rarity` and identify estimated inputs in score explanations. | Confirmed by user |
| Steam eligibility | Where a verified console completion counterpart exists, earn the equivalent regular base requirements and exclude Steam-only extras, the completion trophy itself and DLC. Otherwise use the reviewed original Steam set with the full 1.0 or first-official-set cutoff. | Updated by user November 16 |
| Steam base-game membership | Reviewed stable-ID catalog with exhaustive exclusions and source evidence. Two initial titles are verified; mixed/default/custom sets for other games still need review. | Infrastructure live; coverage expansion pending |
| Missing rarity | PSN and Xbox use the existing 0.50 XP floor when rarity is unavailable. Xbox displays unavailable estimated rarity and refreshes once verified data arrives. Steam also uses that floor and unavailable label. | Implemented |
| Steam achievement changes | Original reviewed IDs define completion. Later new IDs are excluded; removed required definitions require review. Changed membership revisions require a fresh eligibility check. Current native Steam unlocks determine qualification. | Implemented and documented |
| Rarity changes | PSN and Xbox follow current verified catalog rarity. Xbox retains a verified same-membership estimate if a later response loses rarity fields; changed membership without complete rarity becomes unknown. Steam follows current verified rarity and reviewed membership; incomplete estimates use its documented floor. | Implemented |
| Multiple lists and editions | The unit eligible for one completion reward and its interaction with existing stack behavior. | Open |

## Agreed Xbox provisional rarity

Proceed with Mythic support using Xbox's confirmed earned status and a provisional scoring rarity derived from the lowest rarity percentage among its required base-game achievements. Use the same minimum-rarity method selected for Steam. The selected achievement is the rarest required achievement, regardless of unlock order.

Store the estimated value, method, required membership revision, and refresh time. Present the rarity as estimated. Where required membership or rarity is unavailable, preserve the confirmed Mythic and apply the resolved missing-rarity scoring policy. This includes legacy games whose title history confirms Mythic status while their detailed group data is unavailable.

When a native Mythic rarity source becomes available, verify its population and meaning, retain the previous estimate for comparison, and record the new source. Recalculate affected completion XP and cached totals through the scoring version and refresh process. A native rarity can change the resulting score, so make that transition visible in the score explanation.

- [x] Confirm the provisional minimum-rarity method with the user.
- [x] Implement the provisional minimum-rarity method for Xbox.
- [x] Keep Xbox native unlock confirmation independent of the rarity source and record estimated rarity explicitly.
- [ ] Verify a future native source before changing the active rarity input and recalculating scores.

The PlayStation catalog comparison covers 8,876 distinct lists using stored base-game labels. Native Platinum rarity and the lowest other base-game trophy rarity match exactly in 43.5% of lists and differ by at most one percentage point in 88.7%. The median absolute gap is 0.1 points. Some gaps are substantial, and 43 records violate the expected rarity ordering and need data-quality review. This supports retaining the estimated source label and previewing outlier score effects. [PlayStation comparison](../reviews/2026-11-15/PLATINUM_RARITY_COMPARISON.md)

A read-only point simulation excludes those 43 identities and applies the existing curve at unit weight with live storage and per-game rounding. The remaining 1,240 below-1% lists have a median point difference of 0.03 XP, a 95th percentile difference of 0.31 XP, and a maximum of 1.12 XP. Comparing native and estimated rarity on the 101-player global board changes two positions through one strict pair reversal, with the top 10 order preserved. This is a historical unit-weight calibration result. At the selected 5x weight, the below-1% cohort has a median award difference of 0.17 XP and a 95th percentile of 1.52 XP. [Weighted comparison](../reviews/2026-11-15/PLATINUM_COMPLETION_BONUS_PROPOSAL.md) [Score sensitivity analysis](../reviews/2026-11-15/PLATINUM_SCORE_SENSITIVITY.md)

## Proposed Steam base achievement catalog

Maintain one shared achievement membership catalog per Steam AppID, keyed by each achievement's stable API name. Every user of that game uses the same reviewed membership revision for completion eligibility and rarity selection.

Steam documents Achievement Sets with a base-game set and custom sets that can be restricted to DLC. Existing achievements initially belong to the base-game set until developers assign them elsewhere. Official set membership therefore needs coverage checks for games with historical DLC. Live public-page retrieval succeeded for six sampled games, including separate DLC sets and custom mode groups. [Steamworks achievement sets](https://partner.steamgames.com/doc/features/achievements/ach_guide), [verification report](../reviews/2026-11-14/COMPLETION_DATA_VERIFICATION.md)

| Proposed catalog field | Purpose |
| --- | --- |
| Steam AppID and achievement API name | Identify the exact game and achievement independently of translated display names |
| Completion membership | Record base game, add-on, or unknown |
| Source set ID and DLC AppID when available | Retain Steam's grouping and association |
| Evidence source | Record Steam set data or a reviewed reference supporting a manual classification |
| Review state and verification date | Distinguish imported membership from reviewed coverage |
| Membership revision | Identify the exact required set used for a completion and its rarity estimate |

Import verified Steam set membership where available. For games with mixed or unavailable grouping, generate candidate Steam membership by matching the corresponding PlayStation base-game trophies or Xbox BaseGame achievements. Match individual names, descriptions, and requirements for the appropriate edition and record stable source and target achievement IDs. Resolve missing descriptions, ambiguous matches, and extra Steam achievements through another authoritative reference or targeted review. Publisher documentation, release history, and edition-specific achievement guides can support those checks.

A three-game pilot found unique Steam name matches for all 52 Witcher 3 base trophies, all 44 Cyberpunk base trophies, and all 50 Portal 2 base trophies. Witcher 3 and Cyberpunk add-on names also map completely. Portal 2 has one extra Steam achievement, and several descriptions differ or are unavailable, so the pilot records candidate links and verification gaps. Use Steam's own unlocks and rarity percentages after establishing the membership. [Mapping pilot](../reviews/2026-11-15/STEAM_MEMBERSHIP_MAPPING_PILOT.md)

Retain manual corrections across ordinary syncs and record conflicts when Steam's grouping changes. New or unclassified achievements should trigger a membership review. The proposed behavior for an unresolved game is to display completion eligibility as unknown until its required set is established.

The current sync's DLC flag comes from the application's store type and is copied onto its achievement rows. Achievement-level membership needs its own import path to represent DLC achievements that share the base game's AppID. [Steam sync](../../sync-service/steam-sync.js)

- [x] Verify retrieval of Steam Achievement Sets and achievement membership using our available credentials or public Steam data.
- [x] Test cross-platform name and description matching against known PlayStation base and add-on groups in three representative games.
- [ ] Implement stable achievement-ID mappings from verified PlayStation or Xbox requirements to Steam, with requirement evidence, explicit extra-achievement classification, and membership revisions.
- [ ] Pilot the catalog with a game having official DLC sets, an older game with mixed DLC achievements, and a game with verified base-only achievements.
- [x] Store and review membership once per game, then reuse it across users. Initial coverage is two titles.
- [ ] Verify manual corrections survive sync and membership changes produce a reviewable revision.
- [x] Confirm eligibility and lowest-rarity selection use the same reviewed base-game set.

## Database and application scope

Completion scoring spans database storage, sync services, SQL calculations, API responses, Flutter state, and the visible interface. Xbox Mythics need prominence comparable to PlayStation Platinums across player statistics and Xbox leaderboards. Steam completion equivalents need corresponding counts and game completion displays.

### Recommended Steam completion calculation and display

Steam group retrieval is verified. Establish the required set from reviewed membership for each game, including mode groups that belong to its original requirements and exclusions for DLC or later add-on content. Default-group membership and a zero DLC AppID each require coverage review before being used as original-game eligibility.

The backend sync computes base-game progress from the intersection of confirmed user unlock IDs and the reviewed required achievement IDs. A known, nonempty required set is complete when every required achievement is unlocked. Persist the counts, confirmed completion state, nullable completion date, membership revision, estimated rarity, and rarity source in the chosen user progress or completion storage. Final table and column names belong to schema design.

SQL statistics, scoring, and leaderboard queries consume this canonical stored completion state. The Flutter interface reads the state and counts to display progress and an earned `Base game 100%` badge. The completion flag determines the badge, including when a rounded progress percentage could otherwise display 100 early.

Show overall achievement progress and base-game completion with clear labels. For example, 60 of 60 required base-game achievements and 12 of 20 DLC achievements produces an earned base-game completion badge and overall progress of 72 of 80. The completion rarity estimate uses only the 60 required achievements.

Unknown or unreviewed membership remains unresolved completion eligibility until the required set is established. Repeated syncs and membership revisions follow the existing completion retention decisions and prevent duplicate awards. This architecture keeps completion counts, score contributions, and displayed badges consistent across clients.

### Steam completion award representation

Represent Steam base-game completion with a StatusXP completion award. The game-level definition identifies the reviewed required base achievement set, its membership revision, and its estimated rarity source. The user-level completion record confirms that the player earned the award and retains its earned date when known. Final tables can reuse suitable existing completion structures.

Use a unique user, platform, game, and completion-type identity so retries and backfills preserve one earned award for that Steam game. SQL scoring includes its completion contribution alongside earned achievement contributions and exposes that contribution in score breakdowns. The interface displays `Base game 100%` with `Estimated rarity` and the resulting completion XP.

The calculation has three parts. Confirm every required achievement is unlocked, take the minimum rarity percentage among those required achievements, and apply the completion scoring formula and chosen weight. At the confirmed 5x rarity-component weight, an estimated rarity of 0.2% produces `round(0.5 + 11.5 * 5 * (1 - 0.2 / 100)^3, 2) = 57.66` completion XP before per-game total rounding. Award this once alongside the ordinary achievement points; a Platinum uses its existing achievement row.

Completion unlocks, required-set revisions, rarity refreshes, and scoring-version changes need consistent database handling. These are the main implementation dependencies for the award. Record the membership policy and source per review. The November 16 console-equivalent update is applied to Slender and to new console-backed proposals; existing original-Steam reviews require an explicit membership audit before conversion.

### Database changes

| Area | Required work |
| --- | --- |
| Achievement membership | Store Steam and Xbox base-game membership, source grouping, review evidence, and revisions |
| User completions | Persist earned completion type, game identity, source account, nullable date, and the membership revision used |
| Rarity and score inputs | Store completion rarity, its source or estimation method, refresh time, and the chosen scoring version |
| Account statistics | Provide Mythic and Steam completion counts with clear handling of imported totals and individually verified games |
| Leaderboard views and RPCs | Return completion counts and support the chosen ranking rules in both normal and fallback queries |
| Seasonal records | Support completion totals, baselines, gains, and movement using the resolved historical-date policy |
| Score calculations and caches | Include completion rewards consistently in game totals, user totals, potential scores, and refresh jobs |
| Lifecycle and access | Apply existing account binding, merge, deletion, and access-control rules to new stored data |

Choose the final tables and columns during schema design after live payload verification. Review existing completion storage for reuse. Produce versioned migrations and verify compatibility between deployed database, service, and client versions.

### Interface changes

| Surface | Required behavior |
| --- | --- |
| Dashboard and player profile | Show Xbox Mythics with prominence comparable to Platinums, and show Steam base-game completion counts |
| Xbox all-time leaderboard | Include Mythic count, matching icon and labels, game counts, and the chosen primary ranking metric |
| Xbox seasonal leaderboard | Show Mythic totals and period gains with matching baselines and movement calculations |
| Steam leaderboards | Include qualifying base-game completion counts and the chosen ranking metric |
| Game cards and library | Show earned completion badges and support completion filtering where existing library filters apply |
| Game details and achievement lists | Show base-game progress, required achievements, add-on grouping, completion rarity, and earned completion XP |
| Score explanations | Explain how completion contributes to StatusXP, including Steam's lowest-rarity estimate |

Changing the Xbox leaderboard's primary order requires an explicit ranking rule. Proposed ordering is Mythic count followed by Gamerscore as a tie-breaker. Record the final rule before implementing rank movement, pagination, and seasonal comparisons. Steam ranking and tie-breakers also require a recorded decision.

Historical imports require special handling for seasonal boards. A completion first discovered during backfill can have an earlier earned date or an unknown earned date. Establish baseline and attribution rules before using these records for period gains.

The existing Xbox leaderboard repository maps Gamerscore into the primary score and its fallback orders by Gamerscore. Its seasonal path also uses Gamerscore. Update the SQL contracts, models, repository mappings, providers, labels, and row widgets together. [Leaderboard repository](../../lib/data/repositories/leaderboard_repository.dart), [Leaderboard model](../../lib/domain/leaderboard_entry.dart), [All-time interface](../../lib/ui/screens/leaderboard_screen.dart), [Seasonal interface](../../lib/ui/screens/seasonal_leaderboard_screen.dart)

## Delivery phases

### Implementation order

Follow this sequence across the phase checklists below. Validate a small set of games through the complete flow before running the historical backfill.

| Order | Work | Completion condition |
| --- | --- | --- |
| 1 | Verify live Xbox Mythic payloads and rarity availability, and Steam base-game membership retrieval | Representative completed, incomplete, DLC-heavy, and legacy games have documented inputs and source gaps |
| 2 | Set completion weighting, missing-data behavior, retention rules, and platform leaderboard ordering | Calculation examples and database-to-client field contracts describe the intended results |
| 3 | Add database storage and access rules | Migrations support membership, confirmed completions, rarity inputs, and scoring versions with verified lifecycle behavior |
| 4 | Implement normal sync and pilot historical imports | A small set of accounts reliably imports all three completion types, preserves corrections, and survives retries |
| 5 | Implement candidate score and leaderboard calculations | Per-game, per-user, full-refresh, potential-score, and ranking paths agree on the pilot data |
| 6 | Connect the interface to the pilot data | Profiles, dashboard, game and library displays, and leaderboard rows show the intended counts and score explanations |
| 7 | Run the resumable historical backfill and score comparison | Coverage is measured, unresolved records are tracked, repeat runs are stable, and score changes are explained |
| 8 | Activate the new scoring and leaderboard rules, then verify release | Production totals, ranking, seasonal attribution, normal sync, and cache refreshes agree under the released version |

UI layout work can begin after the field contracts in step 2 are settled. Verify integrated behavior against real pilot records before the full backfill. Prepare seasonal baselines and historical-date handling before activating completion-based period gains.

### Phase 1 Verify data and define scoring

- [x] Review the current sync paths and Platinum scoring exclusion.
- [x] Confirm Xbox's published eligibility and retention rules.
- [x] Capture sanitized live title-history and achievement response summaries for completed, incomplete, DLC-heavy, and Xbox 360 games.
- [x] Verify the exact location, types, and availability of Xbox Mythic fields with our credentials, including a two-page continuation check.
- [x] Verify direct achievement contract version 6 and legacy endpoint behavior. Xbox 360 Mythic status is available in title history even when modern completion groups are empty.
- [ ] Verify OpenXBL group forwarding and pagination when its API key is available. Loaded local configuration contains no OpenXBL key.
- [x] Record Steam completion eligibility and lowest rarity estimate rules confirmed by the user.
- [x] Inspect Xbox completion rarity fields in live native responses. No group completion percentage appeared in the sampled responses. Source selection remains in the decision table.
- [x] Verify Steam group membership retrieval and join it to achievement names and individual rarity. Mixed and custom groups require coverage review.
- [x] Compare stored native Platinum rarity with the minimum other base-game trophy rarity, including duplicate handling, missing-group exclusions, and independently checked examples.
- [ ] Resolve the decision table and calculate example completion rewards.

Live title history confirms `achievementSummary.mythicsUnlocked` and per-title `achievement.isMythic`. Modern contract version 6 confirms BaseGame membership arrays, completion state, and completion times for completed samples. The title-history base-game counters behave as group counters in the samples. Required achievement counts come from `achievementIds`. Xbox 360 requires the existing legacy catalog and player progress path alongside title-history Mythic status. [Verification report](../reviews/2026-11-14/COMPLETION_DATA_VERIFICATION.md)

Phase 1 is complete when unlock detection, rarity sources, completion definitions, and the candidate formula are specified well enough to implement and test.

### Phase 2 Store and sync completion data

- [ ] Choose the schema using existing progress, achievement, and completion structures where they preserve the required behavior.
- [ ] Map every database consumer and prepare migrations covering membership, completion records, statistics, leaderboard contracts, access rules, and lifecycle operations.
- [ ] Store catalog-level completion membership independently of user-specific unlock state.
- [ ] Store completion type, source identity, confirmed unlock, nullable earned date, rarity source, rarity value, refresh time, and scoring version where applicable.
- [ ] Preserve an explicit unknown state for unavailable eligibility or rarity data.
- [ ] Import Xbox account Mythic totals and per-game completion data. Account totals may include games absent from the visible title list, so retain their source and meaning.
- [x] Import Xbox original-achievement membership and expose add-on classification where verified.
- [x] Implement Steam completion detection against the verified base-game achievement set, excluding DLC.
- [x] Select the lowest valid base-game achievement rarity percentage for the Steam completion estimate. Preserve valid zero values and apply the documented unavailable-rarity default.
- [ ] Include completion changes and missing completion data in incremental refresh conditions.
- [ ] Make writes safe for retries, concurrent syncs, account relinking, and partial API failures.
- [x] Preserve previously confirmed Xbox Mythics when later responses are incomplete.
- [x] Implement current native eligibility, membership-revision rechecks and explicit review state for removed required IDs.

Phase 2 is complete when repeated syncs reliably persist completion data and ordinary progress remains consistent with its platform source.

### Phase 3 Calculate and compare candidate scores

- [x] Confirm the shared 5x rarity-component weight and preserve the 0.5 XP floor.
- [ ] Implement the common completion scoring rules and platform-specific eligibility inputs.
- [x] Enable native-rarity Platinum scoring in production, including historical definitions, future sync enforcement, and global earned and potential totals.
- [x] Apply the confirmed 5x rarity-component bonus to PlayStation, backfill historical definitions, and verify cached earned and potential totals against source calculations. Xbox completion records and the same 5x rule are now implemented; Steam is now implemented for reviewed sets; broader coverage remains pending.
- [ ] Give each earned completion exactly one score contribution, including PlayStation's existing Platinum row.
- [ ] Update per-user and full leaderboard calculations, game totals, potential scores, and any dependent score queries.
- [ ] Resolve platform leaderboard primary metrics, tie-breakers, rank movement, and seasonal attribution before updating those SQL paths.
- [ ] Produce a preview of old and candidate scores per user, per game, and per completion type.
- [x] Run a read-only PlayStation native-versus-estimated rarity simulation at unit weight, excluding the 43 flagged lists, checking the below-1% cohort, and comparing global leaderboard positions with exact per-game rounding.
- [ ] Inspect representative accounts across platforms, achievement-list sizes, rarity levels, editions, and DLC states.
- [ ] Review flagged PlayStation grouping and rarity-order exceptions before using those lists as completion scoring calibration examples.
- [ ] Confirm that each score difference is explained by the new completion rules and required data corrections.
- [ ] Add focused regression coverage for eligibility, missing rarity, valid zero values, unknown dates, duplicate imports, and agreement between refresh paths.

Phase 3 is complete when the selected weighting has a reviewable score preview and all calculation paths agree.

### Phase 4 Backfill historical completions

- [ ] Build a bounded, resumable backfill with progress tracking and retryable failures.
- [ ] Import existing Platinums, Mythics, and qualifying Steam completions using the same rules as normal sync.
- [ ] Track unresolved records and source coverage by platform.
- [ ] Verify reruns produce stable completion counts and scores.
- [ ] Preserve unknown historical unlock dates and retain account-source provenance.
- [ ] Recalculate candidate scores and assess coverage before activation.

Phase 4 is complete when historical coverage and remaining source gaps are measured and the score preview includes the backfilled data.

### Phase 5 Display and release completion scoring

- [ ] Add completion state, rarity, and XP contribution to relevant Flutter models and repositories.
- [ ] Show Xbox Mythic count, game badges, original-achievement progress, and required-achievement filtering.
- [ ] Update dashboard and profile statistics with Mythic and Steam completion counts.
- [x] Update Xbox and Steam all-time leaderboard rows, icons, labels, sorting, and fallback queries.
- [x] Update affected seasonal leaderboard models, baseline and gain queries, movement, labels, and row displays.
- [ ] Update library and game cards with completion badges and applicable filters.
- [ ] Show completion score breakdowns and meaningful unavailable-data states for all three platforms.
- [ ] Update score explanations to describe the chosen completion weighting and rarity sources.
- [ ] Verify profile, game, library, and leaderboard totals against the same calculation.
- [ ] Prepare the deployment sequence for schema, sync, backfill, calculations, and client compatibility.
- [ ] Record a recovery procedure that restores the prior scoring version and refreshes affected caches.
- [ ] Activate the new scoring version and verify representative production accounts and leaderboard refresh completion.

Phase 5 is complete when normal sync, historical completion data, displayed scores, and refreshed leaderboards agree under the released formula.

## Release acceptance cases

| Case | Expected result |
| --- | --- |
| Earned Platinum with known rarity | One completion contribution using the chosen formula |
| Xbox original list complete with unfinished DLC | Confirmed Mythic remains eligible |
| Later Xbox achievements added | Previously earned Mythic remains confirmed |
| Steam base-game achievements complete with unfinished DLC | One completion reward using the lowest base-game rarity estimate |
| Steam base-game achievement remains locked | Completion reward remains unearned |
| Steam-exclusive achievement remains locked | Excluded when outside a verified console-equivalent requirement set; required when explicitly part of a Steam-only game’s reviewed original set |
| Steam achievement was introduced after launch through an update or event | Excluded from the required completion set and its estimated rarity |
| Steam DLC achievement unlocks or its rarity changes | Completion eligibility and rarity selection use the base-game set |
| Steam base-game rarities are 10%, 20%, and 30% | Completion rarity estimate input is 10% |
| Steam achievement set changes | Behavior matches the documented retention rule |
| Completion rarity unavailable | Consistent score and display under the resolved missing-data policy |
| Historical completion with unknown earned date | Unlock remains valid with an unknown date |
| Retry, overlapping sync, or backfill rerun | Stable completion count and score |
| API timeout or incomplete group response | Previously confirmed data survives and unresolved work can retry |
| Multiple editions or platform lists | Reward count follows the documented list and stack rules |
| Full refresh compared with per-user refresh | Identical totals for the same data and scoring version |
| Historical backfill | Equivalent result to normal sync for the same inputs |
| Xbox leaderboard and fallback | Identical Mythic counts and ordering under the chosen ranking rule |
| Leaderboard ties and pagination | Stable order and correct rank movement under the chosen tie-breakers |
| Seasonal historical imports | Gains follow the resolved earned-date and baseline policy |
| Dashboard, profile, game cards, and leaderboards | Consistent completion counts with distinguishable unknown data |
| Account merge, relink, or deletion | Completion records follow the existing identity and lifecycle rules |

## Next work

The following order reflects production and repository checks on November 16, 2026. Older phase checkboxes above include historical planning items whose implementations are described in the progress record.

1. Completed November 16. The personal normal Steam sync confirmed Rust at 48/48 required achievements, awarded 39.15 completion XP at 12.4% estimated rarity, raised Steam completions to three and combined completions to 204, and reduced pending reviews to four. Account StatusXP is 78,797 and matches the canonical per-game sum.
2. Validate a positive Xbox Mythic through the normal provider-to-app path. Production currently has zero per-title Mythic awards. Database and widget tests cover positive awards, but an account with a genuine earned Mythic is needed to verify live import, estimated rarity, count, score and leaderboard behavior together. Also check an Xbox 360 title and incomplete DLC when suitable account data is available.
3. Complete the mobile acceptance pass and prepare the native release. Android was tested in the separate StatusXP Test package. Test iOS and the intended signed release builds, check existing-install updates and sign-in retention, and recheck dashboard, game details, all-time and seasonal boards. Verify any remaining library/game-card badge and filtering requirements against the current interface. Then submit the Android and iOS releases with the completion UI and release notes. Store publication is still pending.
4. Finish the three Steam investigations for Game of Thrones, Marbles on Stream and Rust Staging Branch. Slender is now verified against its PS5 completion requirements. Audit earlier Steam reviews where an appropriate console counterpart could change their membership under the November 16 console-equivalent rule. Expand reviewed coverage as other users introduce additional games.
5. Complete the user-facing scoring explanation and review the wider Analytics score-breakdown requirement. Explain the 5x rarity component, estimated Xbox/Steam rarity, required base set, pending review, unavailable rarity and rounding. Include a release announcement describing what users gain after sync and app update.
6. Continue data coverage work. Reconcile inaccessible Xbox titles and account-summary differences, review the 43 flagged PlayStation rarity-order records, and verify OpenXBL forwarding when credentials are available.

The backend and web scoring changes are deployed. Legacy Xbox/Steam leaderboard APIs and cache fields were successfully read on November 15 for older-client compatibility. The new mobile visuals require a store update.

## Progress record

| Date | Completed work | Next dependency |
| --- | --- | --- |
| November 14, 2026 | Recorded the three-platform scoring scope, reviewed existing exclusions and sync behavior, and established the phased checklist. | Live API verification and completion rarity sources |
| November 14, 2026 | Confirmed Steam completion requires every base-game achievement and uses the lowest base-game achievement rarity as its completion estimate. DLC is excluded from eligibility and rarity selection. This supersedes the earlier average rarity rule. | Verify Steam base-game membership and Xbox completion rarity |
| November 14, 2026 | Added a proposed shared Steam membership catalog using official Achievement Sets where verified and reviewed mappings for mixed or unavailable grouping. | Verify set data retrieval and pilot membership coverage |
| November 14, 2026 | Expanded scope to cover database migrations, player statistics, Mythic prominence, Xbox and Steam leaderboards, seasonal calculations, library displays, and lifecycle handling. | Resolve ranking rules and verify data contracts |
| November 14, 2026 | Recorded the implementation order with an integrated pilot before historical backfill and scoring activation. | Verify live platform data |
| November 14, 2026 | Verified direct Xbox Mythic totals, modern groups, completed dates, legacy behavior, pagination, public Steam grouping, and rarity joins. Recorded sanitized samples and remaining source gaps. | Settle scoring and ranking rules, review Steam membership coverage, and verify OpenXBL when credentials are available |
| November 15, 2026 | Recommended proceeding with lowest required base-game achievement rarity as a provisional Mythic estimate, with source tracking and a defined transition to verified native rarity. | Finalize the provisional rule, completion weighting, and ranking decisions |
| November 15, 2026 | User confirmed the lowest required base-game achievement rarity as the provisional Xbox Mythic estimate, matching Steam's method. PlayStation uses native Platinum rarity. | Settle completion weighting and ranking decisions |
| November 15, 2026 | Compared 8,876 distinct PlayStation trophy lists. Median absolute gap is 0.1 percentage points, 43.5% match exactly, and 88.7% are within one point. Saved the comparison, checked six examples independently, and flagged 43 rarity-order exceptions. | Preview completion weighting against representative games and outliers, and review flagged records |
| November 15, 2026 | Scored 8,833 qualifying lists with native and estimated rarity using the existing curve at unit weight. Verified 10,617 game totals against the live calculator. The 101-player board has one strict ordering reversal between the two simulated rarity sources. Saved the analysis, anonymized projections, and read-only SQL. | Compare candidate completion weights and resolve ranking rules while retaining the data-review exclusions |
| November 15, 2026 | User reaffirmed the minimum required base-game achievement percentage for both Xbox and Steam completion scoring and confirmed that these values must be labeled as estimates. | Settle completion weight and leaderboard ordering |
| November 15, 2026 | Recorded the recommended Steam completion architecture. Backend sync calculates completion from reviewed required IDs, database storage supplies canonical progress and completion, and the interface displays base-game completion separately from overall achievement progress. | Finalize schema and remaining scoring and retention decisions |
| November 15, 2026 | Tested PlayStation-to-Steam membership candidates for Witcher 3, Cyberpunk 2077, and Portal 2. All reference base trophies have unique name matches. Recorded description gaps and Portal 2's extra Steam achievement for verification. | Implement stable-ID matching and resolve requirement and edition exceptions |
| November 15, 2026 | User confirmed day-one base-game achievements define Steam completion, including original Steam exclusives. DLC and post-launch update or event achievements are excluded from both eligibility and estimated rarity. | Verify release timing and content membership for unmatched Steam achievements |
| November 15, 2026 | Recorded a dedicated StatusXP Steam completion award as the representation of earned base-game 100%, with a game-level definition, user-level earned record, unique award identity, estimated rarity, and completion XP breakdown. | Finalize completion weight, retention behavior, and database schema |
| November 15, 2026 | Applied native Platinum scoring at 1x to 9,698 production definitions and refreshed all StatusXP totals. Verified 56 players gained a combined 35,770 XP with zero cache discrepancies. Added legacy sync enforcement, passing scoring regressions, and a local dashboard pagination correction. | Release local application updates, review flagged data, and continue Xbox and Steam completion implementation |
| November 15, 2026 | User supplied earlier planning context confirming an additional rarity-based completion bonus. Prepared read-only 5x and 10x rarity-component previews with the floor preserved, and retained the existing live 1x rule pending the bonus decision. | Select the completion rarity weight, then implement and backfill the bonus |
| November 15, 2026 | User selected 5x on the rarity component for Platinum, Mythic, and Steam base-game 100% completion awards, retaining the 0.5 XP floor and ordinary achievement formula. | Apply and verify the PlayStation bonus; use the same weight when Xbox and Steam completion records are implemented |
| November 15, 2026 | Applied the confirmed 5x rarity-component weight to all 9,698 production Platinum definitions. Verified 55 players gained a combined 113,805 XP beyond the initial 1x release, with no losses, native-rarity changes, invalid award values, cache discrepancies, or persistent fixtures. All 89 sync tests and the rolled-back database rehearsal passed. | Release local sync and client changes; implement Xbox and Steam completion storage and eligibility using the same weight |
| November 15, 2026 | Released Xbox Mythic database storage, native sync import, original BaseGame minimum-rarity estimate, 5x completion scoring, separate Mythic rank history, seasonal attribution, and dashboard/leaderboard web changes. Tables begin empty and populate on normal user sync. Verified 95 sync tests, 16 Flutter tests, joint PSN/Xbox SQL rollback assertions, zero pre-sync score changes, and healthy Railway/web deployments. | Observe first user sync coverage; ship native mobile UI updates; continue Steam membership and completion work |
| November 15, 2026 | Verified and released potential-score refreshes for all owners when Mythic catalog points change, plus dashboard/library per-game award totals using the same single rounding step as canonical scoring. | Observe normal user syncs and native mobile release adoption |
| November 15, 2026 | User confirmed Steam Completions on the dashboard, Base Game 100% for the earned game badge, and Total Completions for the platform milestone sum. Released reviewed Steam membership/progress storage, normal sync, 5x estimated rarity awards, dashboard totals, all-time/seasonal leaderboards and game totals. Initial coverage is Witcher 3 and Cyberpunk 2077; other games remain pending review. Passed 98 sync tests, 22 Flutter tests, three-platform SQL rehearsal, clean production verification and healthy Railway/web releases. | Expand reviewed Steam membership, observe user syncs, and ship native client updates |
| November 15, 2026 | Tested an isolated Android build on the connected Samsung phone with the user signed in. Matched displayed counts and StatusXP to backend data, verified Steam/Xbox all-time and Steam seasonal screens, and fixed mobile footers that mislabeled pending review as AVG/GAME. Updated the test app and production web; 18 relevant Flutter tests passed and runtime crash/layout checks were clean. | Run the first personal Xbox Mythic-aware sync, expand Steam membership reviews and prepare native store releases |
| November 15, 2026 | Reviewed Steam-only Playrooms from official Steam/developer evidence and added its 30 original achievement IDs. A normal phone-triggered sync verified all 30, awarded one completion, reduced pending reviews from 35 to 34, and raised account StatusXP by 45 after game rounding. The phone displayed 1 Steam Completion and 202 Total Completions. | Continue reviewing pending games using Steam-only evidence or appropriate console references; no per-user count overrides |
| November 15, 2026 | User requested that the Xbox dashboard footer mirror PlayStation with average achievements per game. Updated the known-count footer to use ordinary Xbox achievements divided by tracked Xbox games, rounded consistently with PlayStation; unknown Mythic state retains the sync prompt. Targeted dashboard tests passed. | Verified 12 AVG/GAME on the connected phone and deployed the web update; include the change in the next native store release |

| November 15, 2026 | Audited all 34 personal pending Steam games. Applied 28 exhaustive reviewed sets, including original Steam-exclusive requirements and explicit DLC/update exclusions. Recorded six unresolved cases with source evidence and next actions. Confirmed full 1.0 as the Early Access cutoff. [Review](../reviews/2026-11-15/STEAM_PENDING_GAMES_REVIEW.md). | Resolve the first-achievement-set exception, episodic-season timing, removed originals, seasonal additions and test-branch eligibility |
| November 15, 2026 | Confirmed the first batch through normal Steam sync: 2 Steam completions, 203 combined completions and 78,648 StatusXP. All 28 approved sets match production membership on readback. Rust is expected to qualify after the next allowed sync; a follow-up sync hit the normal cooldown. | Next permitted Steam sync should evaluate three outstanding revisions and leave six genuine review exceptions |
| November 15, 2026 | User approved the first official achievement set for games with no launch achievements. Reviewed and applied PUBG (37 initial achievements, March 9, 2018) and Monos (25, December 22, 2023). The original 34-game batch now has 30 approved sets and four unresolved cases. | Normal Steam sync evaluates the new membership revisions; continue the four documented investigations |
| November 15, 2026 | Added and deployed automatic global Steam review discovery, durable leased jobs, schema history, official evidence collection, exact PlayStation/Xbox reference proposals, paginated catalog reads and guarded reuse of identical reviewed Steam sets. New/ambiguous original scopes remain explicit operator reviews. | Monitor proposal coverage and expand trusted automation only with sufficient original-scope evidence |
| November 16, 2026 | User completed a normal Steam sync. Rust qualified at 48/48 with 39.15 completion XP at 12.4% estimated rarity. Confirmed 3 Steam completions, 204 combined completions, 4 pending reviews and 78,797 StatusXP, matching the canonical calculator. | Positive Xbox Mythic account validation and native mobile release remain outstanding |
| November 16, 2026 | Confirmed Slender PS5 is already present at 21/21 with its earned Platinum. User approved console-equivalent Steam completion. Saved 20 matching regular requirements and excluded I Escaped? from qualification and estimated rarity. Added renamed-requirement matching and console-equivalent review proposals. Verified 115 sync-service tests and 6 Steam widget tests. | Three Steam investigations remain. Next normal sync evaluates Slender’s new membership revision. Audit prior reviews under the updated console-equivalent policy. |
