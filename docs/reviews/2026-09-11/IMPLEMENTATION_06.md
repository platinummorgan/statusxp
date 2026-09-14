# Dependency security updates — SX-010

Date: 2026-09-11. Implemented locally; deployment verification pending.

The initial production npm audits reported two high-severity package findings at the project root and four affected packages in `sync-service` (one high, three moderate). Both final full audits, including development dependencies, report zero known vulnerabilities. This describes the npm advisory database result at the time of the check, not a guarantee that every dependency is free of defects or that each original advisory was exploitable in this app.

## Changes

| Lockfile | Package | Previous locked version | Updated version |
| --- | --- | --- | --- |
| Root | brace-expansion | 1.1.14 | 1.1.18 |
| Root | fast-uri | 3.1.2 | 3.1.7 |
| Sync service | body-parser | 1.20.5 | 1.20.8 |
| Sync service | form-data | 4.0.5 | 4.0.6 |
| Sync service | qs | 6.15.2 | 6.16.0 |
| Sync service | hasown | 2.0.3 | 2.0.4 |
| Sync service | side-channel | 1.1.0 | 1.1.1 |

Express remains on the locked 4.22.2 release. That release pins an affected qs version, so `sync-service/package.json` now overrides qs to 6.16.0. Remove the override only after the parent dependency resolves a patched version without it, then repeat the parsing tests and audit. No direct dependency major-version upgrades were introduced.

The root findings enter through serve's configuration/glob dependencies. The worker uses Express JSON parsing and its default query parser. The form-data package enters through the OpenAI SDK's node-fetch type dependency; the activity generator currently sends JSON chat requests, and this review did not identify a user-controlled multipart upload path. All affected packages were patched regardless of these reachability observations.

References: [brace-expansion mitigation bypass](https://github.com/advisories/GHSA-rgw5-rvv9-x895), [fast-uri malformed IPv6 handling](https://github.com/advisories/GHSA-f65p-4m7j-42xc), [body-parser size enforcement](https://github.com/advisories/GHSA-v422-hmwv-36x6), [qs unsafe isBuffer handling](https://github.com/advisories/GHSA-4mjr-xmp4-gh2g), [form-data multipart injection](https://github.com/advisories/GHSA-hmw2-7cc7-3qxx). The saved audits contain the complete advisory lists.

## Validation

- Both full npm audits are clean.
- Fresh production installations from each package/lockfile pair succeeded in isolated temporary directories using `npm ci --omit=dev --ignore-scripts`. Lifecycle scripts were intentionally not exercised; the unchanged development Supabase CLI was not installed by these production checks.
- All 16 Node tests passed against the clean worker installation. New tests exercise Express nested query parsing, Unicode JSON, malformed JSON rejection, the default body-size limit, and the patched qs round trip. Existing authorization, activity-feed, and leaderboard-retry tests remain green.
- The freshly installed serve CLI served the existing release build's root, catalog/game deep links, and JavaScript asset correctly. No new Flutter build was necessary because Dart code and its dependency lockfile were unchanged.

## Deployment

Deploy with the updated lockfiles using clean installs. Include the qs override from the worker package manifest. Verify the web host and worker HTTP routes after deployment. If deploying the combined working tree, follow the preceding batches' prerequisites, including the leaderboard queue migration before the Railway worker. This dependency-only batch introduces no additional schema changes.

Evidence: [root before](dependencies-root-before.json), [worker before](dependencies-sync-before.json), [root after](dependencies-root-after.json), [worker after](dependencies-sync-after.json), [clean-install tests](dependencies-tests.txt), [web serving smoke check](dependencies-web-smoke.txt).
