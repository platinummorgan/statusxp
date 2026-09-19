# First implementation batch

Date: 2026-09-11. Tasks: SX-004, SX-005; partial verification of SX-001.

Status: implemented locally. No production deployments or database writes were performed. Track release completion in the [improvement checklist](../../../_state/IMPROVEMENT_TODO.md).

## Changes

- Added a shared administrative authorization gate to eight Edge Functions. Trusted automation must supply the service-role bearer token. Human administrators must use a Supabase-verified user token whose ID appears in the server-managed `STATUSXP_ADMIN_USER_IDS` allowlist. An absent allowlist permits service-role automation only. Client-supplied metadata is never used to grant access.
- Denied requests cannot execute the wrapped operation. Wrong methods are rejected, preflight requests do no work, and responses disable caching.
- `get-users` now selects only identity fields rather than returning complete profile rows. `force-stop-syncs` checks database errors before reporting success. Its multiple writes remain nontransactional; a failed call can require reconciliation.
- Retired `test-psn-auth` with an authenticated HTTP 410 response. It no longer logs the sync secret or starts a hardcoded user's sync.
- The sync worker fails initialization without `SYNC_SERVICE_SECRET`. Protected routes use constant-time token comparison and never log received authorization headers. The health endpoint remains public.
- Corrected an existing undefined cover URL variable and existing TypeScript errors in the maintenance jobs touched by this change. The icon backfill's numeric success count is preserved.
- The narrow guest shell has an explicit dark background, separate visible sign-in/join controls, and responsive headline spacing and size. Enlarged text switches the desktop shell to the narrow layout sooner.

## Endpoint contract

| Function | Method | Behavior after authorization |
| --- | --- | --- |
| get-users | GET | Five recent profiles, explicit identity fields |
| force-stop-syncs | POST | Global maintenance stop; checks write errors |
| test-psn-auth | GET | Retired diagnostic, HTTP 410 |
| check-sync-status | GET | Existing diagnostic |
| backfill-game-covers | POST | Existing backfill |
| backfill-achievement-icons | POST | Existing backfill |
| twitch-backfill-subscribers | POST | Existing reconciliation |
| twitch-check-expiring-premium | POST | Existing scheduled reconciliation |

## Deployment prerequisites and verification

1. Confirm Railway has a nonblank `SYNC_SERVICE_SECRET` matching Supabase before releasing the worker. Never place this secret or the service-role key in a client build.
2. Confirm scheduled jobs and maintenance callers use the methods above and supply service-role authorization. Configure `STATUSXP_ADMIN_USER_IDS` only if human administrator access is needed.
3. Deploy the changed Edge Functions with their shared modules and the worker, then release the Flutter web build through the project's release process.
4. Verify unauthenticated and ordinary-user requests are denied. Verify authorized behavior in staging using controlled fixtures before running production maintenance. Do not call global stop/backfill jobs merely as production smoke tests.
5. Verify the released guest page and sign-in navigation at 390, 768, 899, and 900 pixels, including enlarged text.

## Read-only production findings

The Supabase inventory lists `get-users`, `force-stop-syncs`, and `test-psn-auth` as active with gateway JWT verification enabled. Downloaded deployed sources for the first two confirm that they lack administrator checks; gateway JWT verification alone does not enforce administrative access. The local diagnostic source logs the sync secret, but its deployed source was not downloaded for comparison.

Supabase's secret-name inventory contains `SYNC_SERVICE_SECRET` and does not contain `STATUSXP_ADMIN_USER_IDS`. Values were not printed. Railway configuration has not been verified.

The read-only PostgreSQL metadata connection failed, so live profile grants/RLS and entitlement permissions remain unverified. SX-001, SX-002, and SX-003 remain open. This batch does not change profile credential storage or purchase fulfillment.

## Validation

All checks below passed on the local working tree. Browser checks do not establish production deployment or live database authorization behavior.

| Check | Result |
| --- | --- |
| `flutter analyze --no-pub` | No issues |
| `flutter test --no-pub` | 40 passed; 8 web-only tests skipped here and run separately in Chrome |
| `flutter test --no-pub --platform chrome test/web_app_shell_test.dart` | 8 passed: four widths × normal/doubled text; visible background, no layout exceptions, working sign-in navigation |
| `flutter build web --release --no-pub` | Passed; existing optional Wasm dry-run incompatibilities remain |
| `npm test` in `sync-service` | 5 passed, including denied/allowed HTTP requests and missing-secret initialization |
| Deno shared admin handler tests | 15 passed, covering authorization, configuration failure, method/preflight handling, and operation errors |
| Deno type checking | All eight changed function entrypoints passed |
| Release build in Chrome | 390, 768, 899, 900, and 1440px loaded without page errors or a stuck loading screen; 390px and 900px screenshots visually inspected |

The Windows Flutter browser-test server returned 404s for local CanvasKit assets and stalled initialization. For this run, a temporary Playwright connection served those requests from the installed Flutter SDK and reloaded the test iframe. No SDK or application code was changed for this workaround. The test file is at the test root to avoid the runner's nested-path issue. The browser runner also reported a missing font manifest; the separate release-build screenshots verify the actual bundled fonts. Future CI should run the browser tests normally on a working Flutter web test environment.

Deno checks used a temporary Deno installation with `--no-lock --node-modules-dir=none`; repository lockfiles were not changed. The release browser preview blocked backend and analytics requests, so it performed no live user actions.

Evidence: [analysis](implementation-analyze.txt), [Flutter tests](implementation-flutter-tests.txt), [Chrome tests](implementation-web-tests.txt), [release build](implementation-build.txt), [browser results](implementation-browser-results.json), [mobile after](home-after-390.png), [900px after](home-after-900.png).
