# StatusXP v1.1.19 Release Notes

## Unreleased additions verified October 15, 2026

The mobile release remains on hold. The signed Android build was installed on a connected Samsung phone; the owner verified creating a platinum card with AI artwork and sharing it successfully to Facebook groups.

- Platinum celebrations support individual cards and collections of up to four games, the StatusXP logo, personal messages, earned dates, and optional PlayStation rarity and notable trophies.
- Game-cover and screenshot backgrounds are free. AI backgrounds require server-verified Premium, with an initial allowance of three per UTC calendar month.
- Sync discoveries produce one persistent celebration per batch. Historical imports use collection language and do not claim old achievements were earned today.
- The consolidated Menu includes Platinum celebrations. Stats refresh after sync completion, and confirmed Xbox unlocks without provider timestamps display without fabricated dates.
- Backend repairs cover score integrity, bounded leaderboard/library reads, account identity checks, sync cancellation, protected credential access, and renewable Twitch authorization.
- Required reconnect steps for affected accounts stay inside the app. No external reconnect messages were sent.
- One-time account-specific recovery data and operational audit evidence are kept outside this public repository. Public migrations retain schema and reusable logic without account rosters.

Validation: 220 Flutter tests passed (nine platform-specific skips), 49 focused edge-function tests passed, and 70 sync-service tests passed. Release web and signed Android builds passed. Live image generation and private image storage were verified. The largest tested collection contained 4,912 platinums; the first 40-card page loaded in approximately 0.8 seconds and grouped discovery in 1.5 seconds.

## Store release notes

StatusXP is faster and more useful throughout. Flex Room now loads more efficiently and can build a showcase from your synced achievements. Co-op requests have richer browsing and session tools. Recommendations now include clearer goals and controls. Game pages show progress with full trophy and achievement details, including Tips, AI Help, and partner search. Premium access, purchase restoration, navigation, and account reliability have also been improved.

## Release highlights

- Faster Flex Room loading, paginated selection, and automatic showcase population.
- Improved co-op discovery, request details, offers, scheduling, completion, and private feedback.
- Smarter game recommendations with goal selection, alternate suggestions, hiding, and reset controls.
- Unified game pages with compact progress and full-width trophy or achievement cards.
- Restored achievement artwork, rarity, StatusXP, earned dates, comments, AI Help, and co-op actions.
- More reliable account-wide Premium access across supported entitlement providers.
- Safer purchase, cancellation, restoration, and AI-credit fulfillment behavior.
- Better phone navigation-inset handling and responsive layouts.
- Faster, bounded game-library and catalog loading.
- General sign-in, account-linking, sync, security, and stability improvements.

## Version

- Marketing version: **1.1.19**
- Build number: **102**

## Deferred work

The dashboard redesign documented in `docs/reviews/2026-09-16/DASHBOARD_REDESIGN_DIRECTION.md` is planning material for a later update and is not part of version 1.1.19.
