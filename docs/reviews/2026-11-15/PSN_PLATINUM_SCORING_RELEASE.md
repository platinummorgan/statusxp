# PlayStation Platinum Scoring Release

Applied to production November 15, 2026. PlayStation Platinums now use the confirmed **5x rarity-component weight**, retaining the 0.5 XP floor. The initial unit-weight rollout is documented below as release history.

## Confirmed 5x completion bonus release

The user selected `round(0.5 + 11.5 * 5 * (1 - rarity_percent / 100)^3, 2)` for Platinum, Mythic, and Steam base-game 100% awards. PlayStation uses native Platinum rarity. Xbox and Steam will use the agreed estimated rarity when their completion infrastructure is implemented; their ordinary achievements have not received this bonus.

The Platinum row stores the full weighted completion award once, with `rarity_multiplier = 1`. Ordinary trophies retain their existing calculation. A 1% Platinum earns 56.29 XP; a 99% Platinum earns 0.50 XP. Unknown rarity keeps the existing 0.50 XP default. The maximum completion award is 58 XP before game-total rounding.

Production verification at 18:39 UTC confirmed:

| Verification | Result |
| --- | --- |
| Platinum definitions recalculated | 9,698 |
| Existing earned Platinum records | 13,654 |
| Players gaining additional XP over the initial 1x release | 55 of 101 |
| Combined additional XP | 113,805 |
| Largest player increase | 15,191 XP |
| Players losing XP | 0 |
| Native rarity changes | 0 |
| Invalid Platinum point values or scoring flags | 0 |
| Cache discrepancies against canonical earned and potential totals | 0 |
| Persistent fixture users or games | 0 |

The [5x migration](../../../supabase/migrations/_manual_production_archive/20261115193000_boost_psn_completion_rarity.sql) replaced the scoring function, backfilled Platinum definitions, and refreshed earned and potential totals atomically. Its database rehearsal passed in a rolled-back transaction, including ordinary trophy values, legacy sync writes, missing rarity, PSN-only scope, and full versus per-user refresh agreement. All 89 sync-service tests passed. [Sanitized verification](platinum-5x-release-verification.json)

The live database enforces the weighted score for the older deployed sync service. Sync-source deployment remains pending because Railway CLI authentication is expired. The dashboard pagination fix still needs a client release.

## Initial 1x release history

## Database result

| Verification | Result |
| --- | --- |
| Platinum catalog definitions enabled | 9,698 |
| Existing earned Platinum records | 13,654 |
| Native rarity values changed | 0 |
| Leaderboard players | 101 |
| Players gaining StatusXP | 56 |
| Combined increase in displayed total scores | 35,770 XP |
| Largest player increase | 6,508 XP |
| Players losing StatusXP | 0 |
| Cache discrepancies against canonical source totals | 0 |
| Persistent test users or games | 0 |

The database verification snapshot was taken at 18:14 UTC. Point totals use two-decimal achievement storage and existing per-game integer rounding. Unearned Platinums contribute to applicable potential scores, and earned Platinums contribute to user totals.

## Scoring and compatibility

The calculation is `0.5 + 11.5 * (1 - rarity_percent / 100)^3`, bounded between 0.5 and 12 XP. The rollout uses a 1x multiplier. Missing rarity follows the existing 0.5 XP default, although all 9,698 backfilled definitions had valid rarity percentages.

The existing achievement trigger now enforces included scoring and a unit rarity multiplier for PS5, PS4, PS3, and Vita Platinum definitions. This also handles the currently deployed sync version sending the old excluded flags. Native rarity updates continue to recalculate points. Ordinary achievement exclusions retain their existing behavior.

The catalog backfill and global leaderboard refresh committed atomically. The applied SQL is archived under the repository's manual production migration workflow. Seasonal StatusXP queries use original earned dates to attribute trophy contributions.

## Source changes

- [PSN scoring helper](../../../sync-service/psn-statusxp.js) now applies the selected 5x rarity component to Platinums and retains their trophy type; ordinary trophies keep the original curve.
- [PSN sync](../../../sync-service/psn-sync.js) calls the helper when writing definitions.
- [Applied migration](../../../supabase/migrations/_manual_production_archive/20261115180000_include_psn_platinum_statusxp.sql) enforces database compatibility, backfills definitions, refreshes earned and potential totals, and verifies score inputs.
- [Database regression assertions](../../../supabase/tests/psn_platinum_statusxp.sql) cover legacy inserts and updates, metadata-only and flag-only Platinums, all PSN platforms, missing rarity, non-PSN scope, ordinary exclusions, earned versus potential points, and full versus per-user refresh agreement.

## Dashboard pagination correction

Normal API verification exposed a pre-existing 1,000-game response cap in the dashboard's score reader. The [repository update](../../../lib/data/repositories/supabase_dashboard_repository.dart) retrieves all pages in a stable platform and game order and discards partial results if a later page fails, allowing the existing cache fallback to supply the total.

Live paged API checks for the three largest sampled profiles returned all 5,991, 5,222, and 1,398 game entries with unique keys. Their computed totals matched the refreshed cache at 184,468, 120,319, and 108,479 XP respectively.

## Validation and deployment status

All 89 sync-service tests passed, including three PSN scoring regressions. The database migration and regression assertions passed together in a transaction that rolled back before the live application. Post-application checks confirmed catalog inclusion, unchanged native rarities, clean fixture rollback, and exact cache agreement with earned and potential source totals.

Ten Flutter dashboard tests passed, including the new exact-page, multiple-page, and partial-failure checks. Targeted Dart analysis found no issues. The paged live API verification confirmed complete totals for the sampled large libraries.

The database change is live. Local sync and dashboard code changes are ready for their application releases. Railway CLI authentication is expired, so the sync-service code deployment remains pending. The deployed service's existing writes are covered by the live database enforcement. The dashboard pagination correction requires a client release to reach existing installations.

The earlier 43 inconsistent native-versus-minimum-rarity comparisons remain in the data-review list. This rollout scores confirmed PlayStation Platinums from their native rarity values, independently of estimated base-trophy membership.

Return to the [completion scoring plan](../../development/COMPLETION_RARITY_SCORING_PLAN.md).

## Subsequent application deployment

The November 15 [Xbox Mythic release](XBOX_MYTHIC_SCORING_RELEASE.md) deployed the prepared PSN 5x sync source to Railway and the dashboard pagination correction to production web. Railway login was restored. Native mobile installations still need a client update for the dashboard changes.
