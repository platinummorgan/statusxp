# Future Version Roadmap

Updated: February 22, 2026
Owner: Product + Engineering

## Purpose

Track candidate features for upcoming releases, including scope, decisions, risk, and rollout plan.

## Current Discussion Queue

### 1. Seasonal Leaderboard User Drilldown

Status: Proposed
Priority: High

#### Problem

Seasonal leaderboard rows currently open Flex Room. For seasonal competition context, users need to see what games actually produced the seasonal gains.

#### UX Decision

Use a dedicated screen (recommended), not a popup.

Reasoning:
- Drilldown content can be long and multi-platform.
- Better readability and sorting on a full screen.
- Cleaner navigation with a normal back button.
- Easier to extend later (filters, sorting, export/share).

#### Expected User Flow

1. User opens Seasonal Leaderboards.
2. User taps a player name.
3. App navigates to a seasonal drilldown screen for that player and selected period/tab.
4. Back returns to the same Seasonal Leaderboard tab/period state.

#### Board-Specific Breakdown Requirements

- `Platinums (PSN)`: per-game platinum gain in current period (example: `God of War -> Platinum +1`).
- `Xbox`: per-game gamerscore gain in current period (example: `Halo 2 -> +50 GS`).
- `Steam`: per-game achievement count gain in current period.
- `StatusXP`: combined cross-platform breakdown showing per-game StatusXP contribution, grouped by platform with subtotals.

#### Scope Rules

- Seasonal leaderboard tap action should open drilldown (not Flex Room).
- All-Time leaderboard remains unchanged and continues to open Flex Room.
- Data must reflect only the active seasonal window (weekly or monthly), matching current seasonal leaderboard period logic.

#### Backend/Data Work (Likely)

- Add one or more RPCs to fetch seasonal per-game contribution by:
  - target user
  - board type
  - period type (`weekly` or `monthly`)
- Reuse `get_leaderboard_period_start(...)` so period boundaries are identical to leaderboard logic.
- Prefer `SECURITY DEFINER` RPC pattern (consistent with existing seasonal RPCs and RLS constraints).

#### Frontend Work (Likely)

- New screen (working name): `SeasonalUserBreakdownScreen`.
- New repository/domain models for drilldown rows.
- Wire seasonal row/name tap to new screen and pass:
  - `userId`
  - selected board
  - selected period
- Keep current seasonal list visuals; only navigation target changes.

#### Acceptance Criteria

- Seasonal leaderboard name tap opens drilldown screen.
- Drilldown totals match leaderboard `period_gain` for selected user/board/period.
- Period boundaries in drilldown match seasonal leaderboard boundaries.
- All-Time leaderboard continues to open Flex Room.
- Back button returns to Seasonal Leaderboards without losing selected tab/period.

#### Effort Estimate

- MVP: 3 to 6 hours
- Polished version (filters, grouped sections, richer UI states): about 1 day

#### Open Questions

- Should non-name area of the row remain tappable, or name-only?
- Should drilldown include trophy type detail for PSN (gold/silver/bronze), or platinums only for this phase?
- Should hidden leaderboard users (`show_on_leaderboard = false`) be blocked from drilldown access?

### 2. Public Full Game History (View Other User "My Games")

Status: Proposed
Priority: High

#### Problem

Users can only browse full game history (`My Games`) for themselves. There is no public equivalent to view another leaderboard player's full cross-platform game list and trophy/achievement progress.

#### Product Goal

Allow users to view another player's complete game history across PSN, Xbox, and Steam in a read-only experience similar to current `My Games`.

#### Expected User Flow

1. User opens All-Time Leaderboards.
2. User taps a player and lands on Flex Room (unchanged).
3. From Flex Room, user taps `View Full Game History`.
4. App opens a public read-only games screen for that target user.

Secondary path:
1. User opens Seasonal Leaderboards.
2. User taps player and lands on seasonal drilldown screen (Feature 1).
3. User taps `View Full Game History` to open same public read-only games screen.

#### Scope Rules

- Keep existing All-Time -> Flex Room behavior.
- Add a clear CTA from Flex Room (and optionally seasonal drilldown) to public game history.
- Public screen should mirror major `My Games` capabilities:
  - platform visibility
  - search
  - sort
  - per-game progress/trophy/achievement summary
- Public screen must be read-only.

#### Backend/Data Work (Likely)

- Add a public-safe RPC for grouped games by target user (or extend existing RPC safely):
  - input: `target_user_id`
  - enforce public visibility policy (likely tied to `profiles.show_on_leaderboard`)
  - return same data shape needed by `UnifiedGamesListScreen`-style UI
- Ensure RLS-safe access pattern for viewing another user's progress/achievements through controlled RPC(s).

#### Frontend Work (Likely)

- New screen (working name): `PublicUserGamesScreen`.
- Reuse existing list components/presentation where possible to minimize UI drift.
- Add navigation entry points:
  - Flex Room action button
  - Seasonal drilldown action button (optional for MVP, recommended for consistency)
- Add lightweight profile header (`Dex-Morgan's Games`) to make context explicit.

#### Acceptance Criteria

- From leaderboard paths, users can open a target player's full game history.
- Data includes all supported platforms for that target user (PSN/Xbox/Steam).
- Screen is read-only (no edit actions, no owner controls).
- Existing `My Games` flow for current user remains unchanged.
- Access rules are enforced for non-public profiles.

#### Effort Estimate

- MVP: 1 to 2 days
- Polished version (extra filters, richer profile context, deep-link support): 2 to 3 days

#### Open Questions

- Should this be available only for users visible on leaderboards, or via broader profile visibility setting later?
- Do we want deep links (`/users/:id/games`) in v1, or navigation-only entry points?
- Should game-achievement details for public users be fully open or partially redacted?

### 3. Leaderboard Freshness Without Manual Refresh

Status: Proposed
Priority: High

#### Problem

Users report that after app update + sync, leaderboard values do not always reflect immediately unless they manually pull to refresh.

#### Product Goal

When a user opens a leaderboard screen, the data should refresh automatically and show up-to-date numbers without requiring manual refresh gestures.

#### Observed Current Behavior

- Sync screens already invalidate leaderboard providers on successful sync.
- Leaderboard screens still depend on cached provider state and do not guarantee "fresh-on-entry" behavior.
- Backend timing can still introduce short delays between sync completion and leaderboard visibility.

#### Proposed Solution (Two-Layer)

1. App Layer: Fresh On Access
- Invalidate/reload leaderboard providers when entering leaderboard screens.
- Add lightweight auto-refresh on resume (`AppLifecycleState.resumed`) when leaderboard screen is visible.
- Keep pull-to-refresh as backup, but not primary mechanism.

2. Backend Layer: Freshness Contract
- Ensure sync completion path updates leaderboard-visible data before declaring sync success.
- Add a freshness signal (for example, `leaderboard_updated_at` or use existing source timestamps) so UI can verify data currency after sync.
- If freshness lags behind latest sync timestamp, perform short auto-retry polling in UI (bounded, e.g., 2 to 3 attempts).

#### Scope Rules

- No user action should be required to see newly synced totals when opening leaderboard screens.
- Preserve current leaderboard ranking logic and sorting.
- Keep refresh overhead controlled (no aggressive constant polling).

#### Frontend Work (Likely)

- `LeaderboardScreen`: invalidate active provider on screen entry.
- `SeasonalLeaderboardScreen`: invalidate current query provider on screen entry.
- Add optional "sync just completed" flag handling to trigger one guaranteed refresh pass when navigating from sync flows.

#### Backend/Data Work (Likely)

- Audit sync completion order to confirm score-relevant writes are committed before success state.
- Add/standardize freshness timestamp exposure for leaderboard reads.
- Add targeted refresh function call where needed for caches still relying on delayed update mechanisms.

#### Acceptance Criteria

- After successful sync, opening All-Time or Seasonal leaderboard shows updated totals without manual pull-to-refresh.
- From cold app launch, leaderboard entry automatically fetches fresh data on first view.
- No noticeable increase in loading errors/timeouts from added refresh logic.

#### Effort Estimate

- MVP (entry invalidation + guarded retry): 4 to 8 hours
- Full hardening (freshness contract + telemetry): 1 to 2 days

#### Open Questions

- Should we show a small "Updating leaderboard..." state for post-sync consistency windows?
- Do we want per-tab refresh throttling (for example, no re-fetch if last fetch < 30 seconds)?
- Should this include Hall of Fame winner spotlight freshness in the same pass?

## Backlog Intake

Use this section for new ideas discussed outside this thread.

| ID | Feature | Problem | Proposed Solution | Priority | Target Version | Status |
| --- | --- | --- | --- | --- | --- | --- |
| F-001 | Seasonal Leaderboard User Drilldown | Seasonal taps open Flex Room instead of period-scoped contribution detail | Dedicated drilldown screen + seasonal RPCs | High | TBD | Proposed |
| F-002 | Public Full Game History | Users cannot view another player's full cross-platform game/trophy history | Add read-only public `My Games` equivalent for target user, reachable from Flex Room and seasonal drilldown | High | TBD | Proposed |
| F-003 | Leaderboard Freshness Without Manual Refresh | Users do not always see synced totals unless they manually refresh leaderboard screens | Add automatic refresh on leaderboard access + backend freshness contract and bounded retry | High | TBD | Proposed |

## Release Planning Notes

- Keep this doc as source of truth for future-version candidates.
- Move items to implementation docs once approved and scheduled.
- Add explicit target version once roadmap sequencing is decided.
