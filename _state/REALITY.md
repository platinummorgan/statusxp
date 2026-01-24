# PROJECT REALITY

## What this project is
StatusXP is a multiplatform gaming achievement tracker app (Google Play, Apple App Store, and Web) that aggregates achievements and trophies across PlayStation (PSN), Xbox, and Steam into a unified gamer profile.

**Core Features:**
- Cross-platform achievement tracking and syncing
- Dashboard with gaming stats and progress
- Display Case for showcasing favorite achievements
- Flex Room for sharing notable unlocks
- Leaderboards and competitive rankings
- StatusXP scoring system (rarity-based points)
- Subscription tiers (Free, Pro, Premium)
- AI Packs (Small, Medium, Large)

## How it runs
- **Frontend:** Flutter 3.9.2 (Dart) - supports iOS, Android, and Web
- **Backend:** Supabase (PostgreSQL database + Edge Functions + Auth)
  - Supabase URL: https://ksriqcmumjkemtfjuedm.supabase.co
  - Auth: Supabase Auth with Google Sign-In + OAuth for PSN/Xbox/Steam
  - Edge Functions: TypeScript/Deno for platform API integrations
- **Database:** PostgreSQL on Supabase (see DATABASE_SCHEMA_LIVE.sql)
  - **31 tables** including:
    - Core: `profiles`, `games`, `platforms`, `achievements`, `user_achievements`
    - Progress: `user_progress`, `user_stats`, `user_sync_history`
    - Features: `display_case_items`, `flex_room_data`, `meta_achievements`, `user_meta_achievements`
    - Sync logs: `psn_sync_logs`, `xbox_sync_logs`, `steam_sync_logs`
    - Premium: `user_premium_status`, `user_ai_credits`, `user_ai_pack_purchases`
    - Social: `achievement_comments`, `trophy_help_requests`, `trophy_help_responses`
    - Leaderboards: `leaderboard_cache` (materialized view for performance)
  - **23 views** for leaderboards, StatusXP scoring, and aggregated stats
  - **68 functions** for business logic, triggers, and data processing
  - **Composite primary keys** on `achievements` and `games` tables (platform_id + platform_game_id + platform_achievement_id)
  - **RLS policies** on all tables for row-level security
  - **Extensions:** pg_cron (scheduled jobs), pgcrypto (encryption), uuid-ossp (UUID generation)
- **Hosting:** 
  - Web: Vercel (Flutter Web build)
  - Mobile: Native iOS/Android apps via App Store/Google Play
  - Assets: Supabase Storage for avatars and achievement icons

**Game System Mapping**
[
  {
    "id": 1,
    "name": "PlayStation 5",
    "code": "PS5"
  },
  {
    "id": 2,
    "name": "PlayStation 4",
    "code": "PS4"
  },
  {
    "id": 3,
    "name": "Xbox Series X|S",
    "code": "Xbox"
  },
  {
    "id": 4,
    "name": "Steam",
    "code": "Steam"
  },
  {
    "id": 5,
    "name": "PlayStation 3",
    "code": "PS3"
  },
  {
    "id": 9,
    "name": "PlayStation Vita",
    "code": "PSVITA"
  },
  {
    "id": 10,
    "name": "Xbox 360",
    "code": "XBOX360"
  },
  {
    "id": 11,
    "name": "Xbox One",
    "code": "XBOXONE"
  },
  {
    "id": 12,
    "name": "Xbox Series X|S",
    "code": "XBOXSERIESX"
  }
]

**Key Dependencies:**
- flutter_riverpod ^2.5.1 (state management)
- go_router ^14.6.2 (routing)
- supabase_flutter (backend integration)
- Various platform-specific packages

## How it deploys
- **Branch that deploys:** `main`
- **Web deployment:**
  - Platform: Vercel
  - Build script: `build.sh` (Flutter web build)
  - Config: `vercel.json` (SPA routing, headers)
  - Build command: `flutter build web --release --no-tree-shake-icons`
  - Dart-defines inject Supabase URL/keys at build time
- **Mobile deployment:**
  - iOS: **CRITICAL**: Must build with `./build-ios.sh` or `flutter build ios --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...` BEFORE opening Xcode to archive. Never build directly in Xcode without dart-defines.
  - Android: Manual via Android Studio → Google Play Console
  - Current version: 1.1.6+77
  - **iOS Build Script**: Use `build-ios.sh` to ensure Supabase credentials are injected properly
- **Database migrations:**
  - **IMPORTANT**: Old migrations were OUT OF SYNC with live database (as of Jan 21, 2026)
  - **Baseline migration created**: `20260121213830_baseline_from_live.sql` - complete snapshot of production
  - Old migrations archived in: `supabase/migrations/_archive_old_migrations/`
  - **Going forward**: Create new migrations from this baseline only
  - **Never**: Modify the baseline migration or apply old archived migrations
  - Location: `supabase/migrations/*.sql`
  - Deployment: Via Supabase Dashboard or CLI (`npx supabase db push`)
  - Always test migrations in local Supabase instance first

## Current state
- **What is working:**
  - ✅ Google Sign-In authentication
  - ✅ PSN account linking and sync (via unofficial PSN API with NPSSO token auth)
  - ✅ Xbox account linking and sync (via OpenXBL API)
  - ✅ Steam account linking and sync (via official Steam Web API)
  - ✅ Dashboard with real-time stats
  - ✅ Game browsing and achievement viewing
  - ✅ Display Case editing and persistence
  - ✅ Flex Room for sharing achievements
  - ✅ Leaderboards (global, friends, weekly)
  - ✅ StatusXP scoring system
  - ✅ Subscription management (Stripe integration)
  - ✅ Web app deployed and accessible
  - ✅ iOS and Android apps in production

- **What is broken/needs attention:**
  - None currently


## Last known good commit
- **Commit hash:** 95e533109e04a8eb9e21ed47bdc6d4e6fa8a9f90
- **Date:** January 22, 2026
- **Notes:** Fixed critical issues #6, #7, #8:
  - Issue #6: My Games achievement navigation (missing platform_id/platform_game_id)
  - Issue #7: Flex Room save persistence (premature cache invalidation)
  - Issue #8: Xbox leaderboard gamerscore calculation (multiplication bug)
  - Migration: 20260122000001_fix_get_user_grouped_games_include_ids.sql
  - Migration: 20260122000002_fix_xbox_leaderboard_gamerscore_calculation.sql
  - Code fix: lib/ui/screens/flex_room_screen.dart (removed early invalidation)

## Critical Files to Know
- `DATABASE_SCHEMA_LIVE.sql` - Complete live database schema dump (source of truth)
- `supabase/migrations/20260121213830_baseline_from_live.sql` - Baseline migration (DO NOT MODIFY)
- `supabase/migrations/_archive_old_migrations/` - Old migrations (reference only, DO NOT APPLY)
- `CRITICAL_AUDIT.md` - Known blockers and issues (READ THIS!)
- `MIGRATION_COMPLETION_REPORT.md` - Recent code migration notes (Jan 21, 2026 - auth.users → profiles)
  - NOTE: This documents CODE changes, not SQL migrations. The SQL migration it references is archived.
- `README.md` - Project overview and tech stack
- `build.sh` - Web deployment build script
- `pubspec.yaml` - Flutter dependencies (version: 1.1.6+77)
- `lib/main.dart` - App entry point
- `lib/ui/screens/` - All screens
- `lib/services/` - Business logic and API integrations
- `supabase/migrations/` - Database schema evolution
- `supabase/functions/` - Edge functions for platform APIs

## Architecture Notes
- **State Management:** Riverpod with AsyncNotifierProvider pattern
- **Routing:** GoRouter for declarative navigation
- **API Pattern:** Repository pattern with service layer
- **Data Models:** Freezed for immutable data classes with Equatable
- **Error Handling:** Unified error types with user-friendly messages
- **Testing:** Widget tests for UI, unit tests for business logic

## Platform API Integration Details

### PSN (PlayStation Network)
- **Method:** Unofficial PSN Trophy API (based on psn-api library patterns)
- **How it works:** User logs in via Sony's official OAuth in WebView → app extracts NPSSO token → exchange for access/refresh tokens → call PSN trophy APIs
- **Storage:** NPSSO token stored in `profiles.psn_npsso_token` (plain text - consider encryption)
- **Rate Limits:** 
  - Free: 3 syncs/day, 2-hour cooldown
  - Premium: 12 syncs/day, 30-minute cooldown
- **Gotchas:** 
  - Token expires after ~2 months, requires re-login
  - PSN API is unofficial, could break
  - Must handle PS3/PS4/PS5/Vita platforms separately

### Xbox
- **Method:** OpenXBL API (third-party service)
- **How it works:** OAuth flow → OpenXBL API key → access to achievements
- **Storage:** Xbox Live tokens in `profiles.xbox_*` columns
- **Rate Limits:**
  - Free: 1-hour cooldown
  - Premium: 15-minute cooldown
- **Gotchas:**
  - OpenXBL may have their own rate limits
  - Requires active Xbox Live Gold/Game Pass for some features

### Steam
- **Method:** Official Steam Web API
- **How it works:** User provides Steam ID + Steam API key (user-generated)
- **Storage:** Steam ID and API key in `profiles.steam_*` columns
- **Rate Limits:**
  - Free: 1-hour cooldown
  - Premium: 15-minute cooldown
- **Gotchas:**
  - User profile MUST be public (not Friends Only or Private)
  - User must generate their own API key from Steam
  - API key can be revoked by user at any time

## Subscription Tiers & Limits

### Free Tier
- 3 PSN syncs/day (2-hour cooldown)
- 1-hour cooldown for Xbox/Steam
- 3 AI guides per day
- Basic features only

### Pro Tier (Not Yet Implemented)
- TBD - middle tier planned

### Premium Tier
- 12 PSN syncs/day (30-minute cooldown)
- 15-minute cooldown for Xbox/Steam
- Unlimited AI guides
- Priority sync queue
- Additional display case slots
- **Payment:**
  - iOS: Apple App Store in-app purchases
  - Android: Google Play in-app purchases
  - Web: Stripe payment integration
- **Price:** Check TERMS_OF_SERVICE.md for current pricing

**UX UPGRADES**
- None currently - all requested upgrades completed!

**REMAINING ISSUES (CRITICAL)**
- None currently

**REMAINING ISSUES (Non-Critical):**
1. ⚠️ 50+ debug print statements in production code (cleanup item, not a blocker)
2. ⚠️ No email verification on signup (acceptable with OAuth, can add later)

## Common Pitfalls & Gotchas

1. **RLS Policies:** Always test with a fresh user account - policies may work for you but fail for others
2. **Migrations:** NEVER modify existing migrations - create new ones
3. **Auth Context:** User ID is only available after auth - check for null everywhere
4. **Platform Syncing:** Each platform has different data structures - don't assume consistency
5. **Web vs Mobile:** Some packages work differently on web (file_picker, path_provider, etc.)
6. **Supabase Limits (Pro Tier):** 
   - Unlimited concurrent connections
   - 8GB database size limit (100GB with add-ons)
   - Edge Functions: 2M invocations/month, higher rate limits than free tier
   - 50GB bandwidth/month (expandable with add-ons)
7. **Token Expiry:** Auto-refresh is disabled - manual refresh every 5 minutes via AuthRefreshService
8. **Testing:** Always test with ACTUAL platform data, not just mocks

## Testing Strategy

- **Widget Tests:** Use ProviderScope to override providers with mock data
- **Integration Tests:** Not yet implemented
- **Manual Testing Checklist:**
  1. Fresh account creation
  2. Link each platform (PSN, Xbox, Steam)
  3. Trigger sync and verify data appears
  4. Test subscription flow
  5. Test display case editing
  6. Test sharing/screenshots
  7. Test leaderboards
  8. Test on both iOS and Android physical devices

## Environment Variables & Secrets

**Build-time (dart-define):**
- `SUPABASE_URL`: https://ksriqcmumjkemtfjuedm.supabase.co
- `SUPABASE_ANON_KEY`: (in build.sh, don't commit to public repos)

**Runtime (Supabase secrets):**
- PSN client credentials
- Xbox OAuth credentials  
- OpenXBL API key
- Stripe API keys
- AI service API keys

**Never commit:**
- API keys in plain text
- User credentials or tokens
- `.env` files with secrets
- Private keys for signing

## Do NOT suggest
- Switching from Supabase to Firebase (committed to Supabase)
- Replacing Riverpod with Provider/Bloc (architecture is set)
- Using unofficial/hacky platform APIs (only official or proven solutions)
- Hardcoding user IDs (use Supabase auth - THIS IS CRITICAL)
- Adding more debug prints (remove existing ones instead)
- Breaking changes without migration path
- Deploying to main without testing first
- Modifying RLS policies without careful review
- Changing subscription tiers without migration plan
- Any changes that would require users to re-link accounts
- Disabling autoRefreshToken (already disabled intentionally)
- "Just use a try-catch" without proper error handling
- Suggesting features that would hit platform API rate limits 