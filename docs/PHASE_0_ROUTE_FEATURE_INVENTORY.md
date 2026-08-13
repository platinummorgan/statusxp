# Phase 0 Route and Feature Inventory

**Audit date:** August 12, 2026  
**Status:** Initial source audit complete; runtime and analytics validation remain.  
**Source inspected:** `lib/ui/navigation/app_router.dart` and routed screen navigation handlers.

## Summary

- 37 `GoRoute` declarations exist.
- 6 routes sit outside `AuthGate`; three are user-facing and three are callback/compatibility routes.
- 31 routes sit inside `AuthGate` and therefore require an authenticated session.
- No canonical public player route exists.
- The canonical game route is only a redirect to the achievement list.
- No canonical achievement-detail route exists; comments are routed as the terminal achievement destination.
- Several screens use imperative `MaterialPageRoute`, preventing stable URLs and reliable web deep links.
- Several production screens exist without a declarative route.
- Premium access is inconsistent at the router layer: some premium screens use activation markers while others rely on screen-level behavior.

## Classification

- **Access:** `PUBLIC`, `AUTH`, or `CALLBACK`.
- **Tier:** `FREE`, `PREMIUM`, `MIXED`, or `SYSTEM` based on visible routing and screen intent. Runtime entitlement enforcement still needs validation.
- **State:**
  - `WORKING` — a substantive implementation exists and no direct source-level terminal defect was found in this pass.
  - `PARTIAL` — useful implementation exists but routing, metadata, access, or important actions are incomplete.
  - `REDIRECT` — contains no durable destination of its own.
  - `SYSTEM` — callback or compatibility route.
- **Connectivity:** `GOOD`, `LIMITED`, or `DEAD END` describes whether the destination leads naturally into canonical entities.

These labels are source-audit findings, not production certification.

## Declarative route inventory

| Route | Destination | Access | Tier | State | Connectivity | Primary finding |
|---|---|---:|---:|---:|---:|---|
| `/landing` | Landing page | PUBLIC | FREE | PARTIAL | LIMITED | Public marketing exists; smooth-scroll action still has a TODO. |
| `/reset-password` | Password reset | PUBLIC | SYSTEM | WORKING | GOOD | Required public recovery destination. |
| `/premium/success` | Purchase result | PUBLIC | SYSTEM | WORKING | LIMITED | Transactional destination. |
| `/twitch-callback` | Twitch OAuth redirect | CALLBACK | SYSTEM | SYSTEM | GOOD | Redirects into settings with callback data. |
| `/login-callback` | OAuth callback | CALLBACK | SYSTEM | SYSTEM | GOOD | Redirects to dashboard/AuthGate. |
| `/auth/callback` | Legacy OAuth callback | CALLBACK | SYSTEM | SYSTEM | GOOD | Compatibility redirect. |
| `/` | Dashboard | AUTH | MIXED | WORKING | LIMITED | Rich launch surface; entity-link consistency requires a dedicated audit. |
| `/get-started` | First-sync onboarding | AUTH | FREE | WORKING | GOOD | Supports platform activation. |
| `/sync-results` | First-sync results | AUTH | FREE | WORKING | LIMITED | Results need canonical entity links throughout. |
| `/weekly-recap` | Weekly recap | AUTH | MIXED | WORKING | LIMITED | Play-next deep-links to the achievement list using query-string metadata. |
| `/invite` | Invite friends | AUTH | FREE | WORKING | LIMITED | Acquisition utility, not connected to public profiles/following yet. |
| `/steam-connect` | Steam configuration | AUTH | FREE | WORKING | GOOD | Platform setup route. |
| `/steam-sync` | Steam sync | AUTH | FREE | WORKING | GOOD | Platform operation route. |
| `/games` | PlayStation-oriented/My Games list | AUTH | FREE | WORKING | LIMITED | Overlaps conceptually with unified games and leads directly to achievements. |
| `/unified-games` | Cross-platform library | AUTH | FREE | WORKING | LIMITED | Uses imperative navigation to achievement lists, so game URLs are not durable. |
| `/games/browse` | Global game catalog | AUTH | FREE | WORKING | LIMITED | Valuable catalog is auth-only and bypasses canonical game routes. |
| `/game/:gameId` | Game detail shortcut | AUTH | FREE | REDIRECT | DEAD END | Not a game hub; redirects immediately to achievements. |
| `/game/:gameId/achievements` | Game achievement list | AUTH | FREE | WORKING | LIMITED | Depends partly on query-string name/platform/cover metadata. |
| `/poster` | Status poster | AUTH | MIXED | WORKING | LIMITED | Strong sharing output; does not resolve to a public profile/entity destination. |
| `/psn-sync` | PlayStation sync | AUTH | FREE | WORKING | GOOD | Platform operation route. |
| `/xbox-sync` | Xbox sync | AUTH | FREE | WORKING | GOOD | Platform operation route. |
| `/flex-room` | Flex Room | AUTH | MIXED | WORKING | LIMITED | Route represents the current user; other users are opened imperatively. |
| `/achievements` | StatusXP meta-achievements | AUTH | FREE | WORKING | LIMITED | Product achievements are distinct from platform achievement detail; naming can confuse. |
| `/coop-partners` | Co-op request board | AUTH | FREE | WORKING | GOOD | Has a routed request-detail child. Needs player/game/achievement entity links. |
| `/coop-partners/:requestId` | Co-op request detail | AUTH | FREE | WORKING | LIMITED | Action flow exists; participant profiles are not canonical destinations. |
| `/achievement-comments/:achievementId` | Achievement comments | AUTH | FREE | PARTIAL | DEAD END | Comments substitute for a canonical achievement-detail page and require composite IDs in query parameters. |
| `/leaderboards` | All-time leaderboards | AUTH | FREE | WORKING | LIMITED | Tapping a player opens Flex Room imperatively instead of a profile route. |
| `/leaderboards/seasonal` | Seasonal leaderboard | AUTH | FREE | WORKING | LIMITED | Player breakdown opens via imperative route. |
| `/leaderboards/hall-of-fame` | Historical winners | AUTH | FREE | WORKING | LIMITED | Winner tap opens Flex Room imperatively rather than a public profile. |
| `/settings` | Settings and connections | AUTH | MIXED | PARTIAL | LIMITED | Broad operational screen; Twitch-channel link remains a TODO. |
| `/analytics` | Premium analytics | AUTH | PREMIUM | WORKING | LIMITED | Activation is marked; charts need canonical entity drill-down. |
| `/sync-intelligence` | Premium sync diagnostics | AUTH | PREMIUM | WORKING | GOOD | Operational utility with activation marker. |
| `/goals-pace` | Premium goal/pace coaching | AUTH | PREMIUM | WORKING | LIMITED | Activation marked; recommendations need canonical entity links. |
| `/rival-compare` | Rival comparison | AUTH | PREMIUM | PARTIAL | LIMITED | No router-level activation marker; entitlement behavior needs runtime validation. |
| `/achievement-radar` | Premium opportunity radar | AUTH | PREMIUM | WORKING | LIMITED | Activation marked; actions should resolve to canonical achievements. |
| `/engagement-hub` | Challenges, activity, play-next | AUTH | MIXED | WORKING | LIMITED | Recommendations deep-link to achievement lists using query-string metadata. |
| `/premium-subscription` | Subscription management | AUTH | SYSTEM | WORKING | GOOD | Purchase/entitlement destination. |

The table contains all 37 `GoRoute` declarations currently present in the router source.

## Non-declarative and unrouted screens

These screens either lack a canonical `GoRoute` or are commonly opened with `MaterialPageRoute`:

| Screen | Current use | Risk | Recommended disposition |
|---|---|---|---|
| `SeasonalUserBreakdownScreen` | Opened from seasonal leaderboard imperatively | No stable URL or web refresh support | Add a player/season route or make it part of the public profile. |
| Other-user `FlexRoomScreen(viewerId:)` | Opened from leaderboards/Hall of Fame imperatively | Flex Room is acting as a substitute profile | Fold into `/u/:handle/showcase`. |
| `TrophyRoomScreen` | Legacy/original showcase screen | Contains multiple dead taps and TODO actions | Defer or retire after useful pieces are merged into canonical profiles. |
| `UpdatesScreen` | StatusXP changelog | No declarative route found in app router | Keep separate from Gaming Pulse and add a settings subroute if still active. |
| `GameDetailScreen` | Older editable detail implementation | Not used by canonical game route | Confirm whether legacy; retire or rename to prevent confusion. |
| Platform connect/login screens | Launched inside platform flows | Some are legitimately transactional | Keep nested, but ensure callback recovery and analytics. |
| `ThemeDemoScreen` | Development/demo surface | Empty handlers and not a product feature | Keep debug-only or remove from release builds. |

## Confirmed connectivity defects

### P0 — Product-spine blockers

1. `/game/:gameId` is a redirect, not a canonical game hub.
2. No canonical achievement-detail route exists.
3. No canonical public player/profile route exists.
4. Catalog and library screens construct `GameAchievementsScreen` directly with `MaterialPageRoute`.
5. Leaderboard and Hall of Fame player taps open Flex Room directly instead of a profile entity.
6. Routed game displays accept human-readable metadata through query parameters instead of loading canonical records solely from identifiers.

### P1 — Important consistency gaps

1. Premium enforcement is not expressed consistently in router configuration.
2. `GamesListScreen` and `UnifiedGamesListScreen` overlap and need a documented product distinction or consolidation.
3. Platform achievements, StatusXP meta-achievements, comments, and co-op requests use related terminology without a shared entity navigation model.
4. Public catalog discovery is unavailable because the catalog resides inside `AuthGate`.
5. Shareable posters do not lead viewers to a public player destination.
6. App updates/changelog and future Gaming Pulse content need explicitly separate information architecture.

### P2 — Cleanup and polish

1. Landing-page smooth-scroll TODO.
2. Settings Twitch-channel TODO.
3. Legacy Trophy Room dead taps and incomplete “View All” actions.
4. Generic icons are used in places where stored achievement imagery is available.
5. Imperative routes create inconsistent browser history and analytics naming.

## Recommended canonical routes

This is the proposed URL contract to validate before Phase 1 implementation:

```text
/u/:handle
/u/:handle/games
/u/:handle/achievements
/u/:handle/activity
/u/:handle/showcase

/games
/games/:platform/:platformGameId
/games/:platform/:platformGameId/achievements
/games/:platform/:platformGameId/achievements/:platformAchievementId
/games/:platform/:platformGameId/community

/leaderboards
/leaderboards/:board
/leaderboards/seasons/:seasonId
/leaderboards/seasons/:seasonId/u/:handle

/pulse
/pulse/news/:contentId
/pulse/events/:eventId
/pulse/releases
```

Use platform codes in public URLs and translate them to numeric platform IDs in the repository layer. Do not place names, cover URLs, or other canonical display metadata in query parameters.

## Phase 0 remaining validation

- Exercise every route on web and at least one mobile target.
- Verify anonymous, authenticated-free, and authenticated-premium behavior.
- Confirm which screens are reachable from current navigation menus.
- Capture actual 404, refresh, back-button, and deep-link behavior.
- Confirm entitlement enforcement inside every premium screen.
- Inspect analytics events and establish baseline funnels.
- Mechanically generate the route count and prevent documentation drift.
- Decide whether `/games` or `/unified-games` becomes the canonical personal library.
- Approve the canonical URL contract before modifying routing.

## Phase 1 entry recommendation

Phase 1 may begin after two decisions:

1. Approve the canonical public identifier strategy for profiles (`handle`) and games/achievements (platform composite keys).
2. Choose the canonical personal library experience and migration path for the overlapping games screens.

The first implementation slice should then create the canonical game shell and route all catalog/library taps through it without removing the existing achievement list.
