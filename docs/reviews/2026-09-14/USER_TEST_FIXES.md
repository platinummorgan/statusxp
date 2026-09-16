# User testing and corrections — 2026-09-14

User reported successful dashboard identity/totals, recommended game/platform navigation, another/reset suggestions, challenge/recap navigation, and persistent dismissal. Co-op browsing and lifecycle were reported successful. The lifecycle environment/accounts/migration versions were not supplied, so this is user-reported evidence and does not close the controlled staging/privacy release checks. Flex Room and remaining layout/sign-out boxes were unmarked and remain pending.

## Premium access

A read-only request to the configured backend confirmed HTTP 404 / PGRST202 for `get_my_premium_entitlement`. The new client had converted this missing-function error into false, incorrectly presenting existing subscribers as non-premium before the migration was deployed.

Added a narrow compatibility reader: use the effective-entitlement RPC first; only PGRST202 falls back to the caller's existing `user_premium_status` record. Expiry and account-identity checks still apply. Explicit inactive RPC results and permission/server errors never fall back. No subscription records, payment data, grants, or production migrations were changed. Existing server-side authorization remains responsible for premium operations; this is client compatibility, not a bypass. The legacy projection remains subject to its existing limitations until the entitlement migrations are released.

SubscriptionService now resolves its Supabase client when needed rather than permanently capturing a possibly uninitialized client. Both premium access and subscription detail reads use the same compatibility reader.

## Desktop navigation and game information

Added Flex Room to desktop Quick links and a visible desktop Menu containing My games, Flex Room, challenges, recap, co-op, premium tools, subscription, and settings.

Game overview now loads catalog achievement/trophy count and base StatusXP independently of personal progress. Queries use the exact platform/game pair and bounded 500-row pages, summing stored base point values. Missing point values display unavailable; errors offer retry. Totals are catalog entries including listed DLC, not earned points or a guaranteed adjusted score. Catalog-grid/card totals remain a separate request pending clarification; no per-card achievement downloads were added.

## Recommendation goal discussion

Proposed: account default plus per-game override for Platinum versus 100% including DLC. Keep non-PlayStation games on achievement completion. Platinum ranking must identify required trophy groups and exclude DLC-only progress; unsupported/unknown group data must be stated rather than guessed. No goal-setting behavior was changed in this batch, pending the user's preference.

Validation: compatibility tests cover missing RPC fallback, explicit inactive result, and permission/server errors. Existing expiry tests remain. Catalog tests cover more than one response page, composite identity filters, and missing XP. Full Flutter suite: 141 passed, 9 existing platform-specific skips. Analysis passed with no issues. Release web build passed with existing optional Wasm compatibility warnings; local preview responded HTTP 200. Local browser automation was unavailable because the debugging Chrome connection was closed; personal premium access still needs the user to refresh and retest.

These corrections are local after the prior GitHub push. They have not been merged, deployed, or applied as database migrations.

## Inline achievements follow-up
The game overview now includes achievements, expanded by default, with independent loading/error retry. Search and earned/unearned filters operate on the complete fetched catalog; requests use stable 500-row batches and the UI displays 20 matches at a time. Secret entries require explicit reveal unless earned. Detail routes are pushed so Back retains the overview and list state. Collapsing retains search text and pagination. Guest viewers see catalog data without personal earned queries.

Validation: widget coverage exercises pagination, secret concealment, search, collapse/reopen, detail navigation/Back and earned filtering. This remains a local change, pending publication and signed-in browser testing.

## My Games timeout screenshot follow-up
The screenshot reports PostgreSQL 57014 from the unified-library request. The repository calls get_user_grouped_games. An older migration aggregates the entire achievement catalog; a later existing migration bounds this to the user's library. Live function contents and query timing remain unverified because the debugging browser connection is unavailable and no database-admin connection was established.

Local recovery: only a private-library 57014 activates a basic user_progress + games(name) query, filtered to the current user, fetched in stable 500-row batches. The UI shows synced achievement counts, search and links to game overviews. Detailed XP/rarity/trophy breakdowns and their sort controls are omitted with an explicit explanation; retry returns to the full view. Other failures have a readable retry action. Public-profile failures never load the viewer's private library.

Validation: two focused tests passed (HTTP pagination/user filters; timeout/search/retry widget flow), focused analysis clean. This handles the failure state, not the server-side timeout root cause. Live SQL verification and signed-in browser testing remain pending; no production migration was applied.

## Developer entitlement correction
After the owner reported that Radar and Goals & Pace were blocked locally and publicly, an authorized read of the identified account showed an active flag with an expired Twitch membership date (March 14, 2026). At the owner's request, a conditional update changed that one record to premium_source=developer, is_premium=true, premium_expires_at=null. A separate read verified the saved entitlement. No schema changes were made. Account details and credentials are omitted.

Local follow-up UI distinguishes verification errors from expired/missing/inactive membership and provides retry. Sync status uses the shared compatibility reader. Four premium tests and affected-screen analysis passed; web build passed. Actual signed-in access must be rechecked by the owner; non-expiring projection preservation against future billing updates remains follow-up work.
