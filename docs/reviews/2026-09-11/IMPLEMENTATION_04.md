# Account state refresh — SX-008

Date: 2026-09-11. Implemented locally; deployment verification pending.

The current-user provider previously read a snapshot from an unchanged authentication service. Cached games, statistics, game progress, engagement, and premium-feature queries that depended on that provider could keep using the previous user ID. The web guest branch also returned before subscribing to authentication events.

The identity provider now watches authentication events. An explicit signed-out event resolves to no user even if a cached snapshot remains; the restored-session snapshot is used before the stream supplies a value. Same-user token refreshes preserve the ID, avoiding unnecessary dependent reloads.

Connected-platform and leaderboard-rank providers now depend on that reactive identity. PSN/Xbox status streams restart on identity changes so their last-known status belongs to the new account. Public library visibility and achievement comments also reload when the viewer changes. Existing game, achievement, statistics, trophy-room, engagement, and premium-feature providers already watch the shared identity and now receive its changes.

The auth gate subscribes before rendering its web guest branch and keys its shell/content by user ID. Account changes discard screen-local state, including dashboard state; same-user token refreshes preserve it. The biometric-enabled check is retained for the current mounted gate/account, then refreshed after an identity change or app resume. Previously a fresh future on every build replaced the child with loading during token refresh.

Riverpod marks identity-dependent asynchronous data as loading while it reloads and rejects completions from obsolete requests. This is dependency refresh, not a global deletion of all cached objects: AsyncValue can retain its previous value during loading. The UI reads that used `valueOrNull` now use `asData?.value`, so retained values in AsyncLoading are not treated as current-account data. This includes library facts, dashboard engagement, rival comparisons, and several action/status reads. The game overview already uses loading-aware rendering; screen-local state is additionally reset at the auth gate.

## Validation

Provider tests simulate restored A → signed out → B, guest → A → signed out → B, token refresh, old responses arriving late, and revisiting cached public game routes. A mocked HTTP client verifies platform profile requests use the new ID and ranks change from A to B, then clear for guests. The route test checks that account changes reset local state while token refresh preserves it. Test users and data are synthetic; no production account changes occur.

Two Chrome tests passed on the actual auth gate: an already-open guest route reacts to login/logout, and account changes reset its child while token refresh preserves it. Browser fixtures mark onboarding complete. The Windows CanvasKit serving workaround described in [batch one](IMPLEMENTATION_01.md) was used again; the browser runner reported its existing missing font-manifest warning. These are auth/state tests, not visual or live-login verification.

## Release verification

Deploy the application and verify guest → login, A → logout → B, dashboard/library/statistics/platform indicators, PSN/Xbox status, public game and achievement pages, and token refresh on web and native. Include biometric unlock and background/resume on a device with biometrics configured. These device and production checks remain pending. No database or Edge Function deployment is required for this batch.

Validation evidence: [analysis](account-analyze.txt) is clean; [full native suite](account-flutter-tests.txt) passed 66 tests with nine web-only tests skipped; [Chrome account tests](account-web-tests.txt) passed both tests. The eight older guest-layout browser tests were not rerun for this batch. [Release web build](account-build.txt) passed with the existing optional Wasm dry-run incompatibility warnings.
