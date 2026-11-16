# Steam completion review automation

Released November 15, 2026. Steam games discovered by normal sync now enter a shared background review pipeline. Evidence collection, schema snapshots, console ID alignment, issue detection, retry scheduling and export preparation run automatically. New original-content decisions still need review when the available data cannot prove timing or membership.

## Automatic behavior

- A catalog trigger records schema ID changes and queues unverified games once globally. Existing pending games were backfilled.
- A Railway worker claims up to three games per minute with ten-minute leases. Provider errors retry after thirty minutes; unresolved evidence is refreshed after seven days. A changed schema invalidates the old worker lease.
- The collector reads public Steam achievement sets, release metadata, current and launch-window official developer news, exact-title PSN lists and Xbox lists with verified native BaseGame membership. It paginates every database catalog read.
- Unique name/requirement alignment identifies required/excluded candidates and missing, extra, conflicting or differently worded achievements. Complete ID alignments can be exported even when flagged descriptions need review. Original Steam-only achievements are never silently discarded.
- A previously reviewed Steam set can be reused automatically for another AppID only with the same exact title, exhaustive unique achievement names and identical nonempty descriptions. The fetched native schema must match stored definitions. A manual needs-review state and an existing verified review are preserved.
- First-seen schema snapshots help future investigations; they do not assert historical launch dates. Original release, full 1.0 and first-official-set rules remain unchanged.

Steam group zero and console title matches alone cannot establish the original Steam set. Valve documents the default base grouping behavior in its [achievement guide](https://partner.steamgames.com/doc/features/achievements/ach_guide).

## Operator workflow

Export a proposal with `node export-steam-completion-review.js APPID OUTPUT.json` from sync-service. The output file is created without overwriting an existing file. A fully mapped proposal includes stable required/excluded IDs, reference mappings, flagged differences and evidence links. A partial mapping exports an investigation report.

Review the original-content scope and flagged differences before approval. Automated proposals require an explicit `--scope-note` and `--scope-evidence https://...` in the existing review CLI. The approval RPC continues to require exhaustive nonempty coverage and queues score refreshes. Normal Steam sync still establishes actual completion and dates; the background review never fabricates unlocks. No new client UI is required for automatic collection; an in-app administration screen has not been added.

## Validation and deployment

- 113 sync-service tests passed, including 15 review automation tests.
- Rolled-back SQL fixtures passed for service-only permissions, exact template reuse, zero-rarity preservation, changed requirements, manual exceptions, concurrent claims, invalidated/expired leases, provider retries and no fabricated player progress.
- Live parser and collector smoke checks passed against current Steam schemas. Baldur’s Gate 3 produced a 53-required/1-excluded candidate while retaining its requirement-review flags.
- Railway deployment d3204318-acea-4f5c-bd29-713b3882e60a succeeded; the production health endpoint reports healthy on Node 20.20.2. The upload contained 28 runtime modules and no credential files.
- All four backfilled jobs were processed automatically without errors. All four remain needs_review, preserving the established unresolved cases.

| AppID | State | Collected schema IDs | Console candidates |
| --- | --- | --- | --- |
| 1170970 | needs_review | 58 | 0 |
| 252330 | needs_review | 21 | 3 |
| 330840 | needs_review | 48 | 0 |
| 700580 | needs_review | 6 | 0 |

Applied database migration: supabase/migrations/_manual_production_archive/20261116010000_steam_completion_review_automation.sql. The previous manual review registries remain in place. [Catalog workflow](../../development/steam-completion-catalog/README.md).
