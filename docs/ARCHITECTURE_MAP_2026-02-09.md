# StatusXP Architecture Map (Live-Verified)
Generated: 2026-02-09

## Runtime Topology
- Client: Flutter app (`lib/`) for iOS, Android, Web.
- Primary backend: Supabase (Auth, Postgres, Edge Functions, Storage).
- Long-running sync backend: Railway Node service (`sync-service/`).
- Web hosting: Vercel (`vercel.json` + `build.sh`).

## App Boot and Core Runtime
- Entry point: `lib/main.dart`.
- Boot sequence:
  - Initializes Firebase Analytics.
  - Initializes Supabase with PKCE auth flow.
  - Starts auth refresh handling and lifecycle resume refresh.
  - Starts interrupted sync resume checks.
  - Runs `MaterialApp.router` using GoRouter config from `lib/ui/navigation/app_router.dart`.

## Navigation
- Router file: `lib/ui/navigation/app_router.dart`.
- Auth wrapper: `ShellRoute` with `AuthGate`.
- Premium route is now registered:
  - Path: `/premium-subscription`
  - Screen: `PremiumSubscriptionScreen`

## Platform Subscription Flows
- Premium screen: `lib/ui/screens/premium_subscription_screen.dart`.
- Web:
  - Uses Stripe checkout and customer portal via edge functions.
- iOS/Android:
  - Uses native in-app purchase flow via `SubscriptionService`.
- The route layer does not change billing logic; it only resolves navigation.

## Sync Pipeline
- Start sync:
  - App invokes `psn-start-sync`, `xbox-start-sync`, `steam-start-sync`.
  - Edge function validates user/profile and creates sync log.
  - Edge function forwards to Railway `/sync/{platform}` endpoint.
- Execute sync:
  - Railway worker runs platform-specific sync module and updates DB.
- Stop sync:
  - App invokes `*-stop-sync`.
  - Edge function forwards to Railway `/sync/{platform}/stop`.
  - Worker checks cancellation and exits gracefully.

## Live Database Snapshot Source of Truth
- Current live schema dump:
  - `sql_archive/DATABASE_SCHEMA_LIVE_2026-02-09.sql`
- Live schema counts (from dump):
  - Tables: 38
  - Views: 7
  - Materialized views: 1
  - Functions: 79

## Schema Alignment Notes (Live vs App Code)
- Confirmed live:
  - `psn_sync_logs`, `xbox_sync_logs` exist.
  - singular `psn_sync_log`, `xbox_sync_log` do not exist.
  - `app_updates` exists.
- Confirmed missing in live dump:
  - `notifications`
  - `user_trophies`
  - `user_ai_guides`
- Implication:
  - Any code path that writes/reads those missing tables can fail unless guarded.

## Operational Artifacts Generated
- Live table stats:
  - `sql_archive/LIVE_TABLE_STATS_2026-02-09.txt`
- Full inspect report bundle:
  - `sql_archive/inspect_report_2026-02-09/2026-02-09`

## Immediate Stability Priorities
1. Keep sync status functions aligned to plural sync log tables only.
2. Audit `notifications` usage and either create table or remove writes.
3. Audit delete-account function for references to legacy tables.
