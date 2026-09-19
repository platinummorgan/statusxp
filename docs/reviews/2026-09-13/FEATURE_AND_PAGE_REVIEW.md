# Feature and page review — September 13, 2026

Reviewed the signed-in production dashboard, Flex Room, and co-op page through Chrome DevTools, alongside the local Flutter implementation. This is a review and revised implementation priority, not a deployed change. No requests, offers, purchases, or account settings were submitted.

## Existing features to improve, rather than duplicate

| Experience | Existing implementation | Opportunity |
| --- | --- | --- |
| First sync | `first_sync_onboarding_screen.dart` guides platform selection and connection. | Improve the payoff after sync; do not build another connection wizard. |
| What to play next | `next_best_action.dart`, dashboard action card, and engagement-hub recommendations already exist. | Surface them consistently and improve relevance beyond highest completion percentage. |
| Return visits | Daily momentum/challenges, streaks, and weekly recaps already exist. Recaps include standout unlocks and sharing. | Connect these experiences and make them discoverable on desktop. |
| Gaming identity | Flex Room already has featured achievements, a superlative wall, editing, and recent highlights. | Make it faster, more readable, and easier to showcase. |
| Co-op help | Requests, offers, acceptance, platform contact details, and completion already exist. | Turn the disconnected request list into a useful session-planning experience. |

The live desktop dashboard displayed totals, platform summaries, recent games, and quick links, but no next-action, weekly-recap, or daily-momentum cards. The separate `web_desktop_dashboard.dart` implementation does not reference those widgets. They are wired into `new_dashboard_screen.dart`. Feature visibility across layouts is therefore a concrete improvement opportunity.

## Flex Room: measured request overhead

One signed-in desktop reload, existing browser cache, no CPU/network throttling:

- 55 Supabase REST requests.
- 16 `user_achievements`, 16 `achievements`, and 16 `games` requests: 48 requests to hydrate configured tiles.
- Three profile requests, two selected-title requests, one Flex Room configuration request, and one recent-highlights RPC account for the other seven.
- Configuration request: approximately 1,094–1,237 ms after navigation.
- Tile requests started at approximately 1,251 ms; the final game response completed at approximately 1,942 ms.
- Observed shell LCP: 109 ms; CLS: 0. These do not represent completion of the canvas-rendered Flex Room. The data timings above are not a measurement of the exact moment the final card became usable.

The code confirms sequential ownership → achievement → game requests for every tile, including repeated achievements. Some picker paths load up to 50 rows and then hydrate them one at a time. Auto-fill makes twelve category calls and then separately hydrates their results. Profile loading is scheduled from both `initState` and `didChangeDependencies`.

First implementation milestone:

- [x] Batch tile hydration using composite platform/game/achievement identities and deduplicate repeated tiles per load. Implemented locally in batch 20; 16 tiles plus duplicates use three requests in regression tests.
- [x] Remove duplicate profile/title loads and guard account changes/stale responses. Local screen tests verify one profile and one title request.
- [x] Automatically populate new and saved-empty rooms from earned achievements; preserve existing configuration during automatic completion and provide a sync action when no achievements exist. Implemented locally in batch 20.
- [ ] Load showcase content independently from recent highlights and optional auto-fill. Batch 29 removes highlights from showcase loading and fetches them only on Recent Flexes, with independent error/retry. Optional auto-fill isolation remains open.
- [ ] Preserve user selections, enforce owner-only saves, and make failed saves restore the actual saved state. Batch 20 preserves saved keys during automatic completion, restricts automatic writes to the owner, and restores editing after failed saves. Live authorization verification remains open.
- [ ] Bound and batch picker queries; retain search/filter correctness. Batch 30 adds 300 ms debounce, current-future reuse, stale-result suppression, clean search transitions, and failed-read retries. Batch 31 adds 30-row RPC response pages per platform variant/game, stable ordering, Previous/Next, retry, and search reset. Live RPC range behavior, internal query cost, and large-library verification remain open.
- [x] Reduce the tall desktop header and excessive artwork height so achievement names and rarity are visible sooner. Implemented locally with four desktop columns and a smaller header; 390/1240-width layout tests pass.
- [ ] Repeat the same-account browser measurements and add request-count/identity/save regression checks. Report before/after results rather than promise an unmeasured speedup.

The live page also labeled the showcase “Last updated 222 days ago.” The label should distinguish editing the showcase from syncing achievements so it does not imply all gaming data is stale.

## Co-op: usefulness and presentation

The co-op reload made two REST requests: a profile lookup and the open-request query. The latter took approximately 187 ms and ended approximately 1,393 ms after navigation. Shell LCP was 92 ms, CLS 0. This run does not show the same query explosion as Flex Room; larger communities and slower devices remain unmeasured.

Desktop inspection showed full-width, mostly empty cards with game/achievement text and identical Offer Help buttons. Requests ranged from 17 days to several months old. There was no game search, primary create-request action, or session overview. A 390 × 844 viewport was also captured; this was a visual spot check, not a completed accessibility audit.

Code findings:

- Creation is reached through an unearned achievement in a game's achievement list. The co-op page tells users to create requests without providing that path.
- `getRequestsIOfferedHelpOn()` exists but has no UI callers: helpers lack a clear place to revisit their offers.
- Availability is free text, without structured date/time/timezone or participant requirements.
- Network errors can become an empty list, making failures look like an empty community.
- Open requests are fetched without explicit pagination; platform filtering occurs in the page after fetching.
- Acceptance updates the offer and parent request in separate calls. It writes `assigned`, while list styling/model documentation use `matched`; reconcile actual schema/status behavior as part of the user flow.

Second implementation milestone: overhaul the existing page as a co-op hub.

- [x] A clear opening section with **Find partners** and **Request help**, connected to the existing achievement-selection flow. Implemented locally in batch 21 with a guided Choose a game action.
- [x] Responsive cards with game artwork, platform, specific goal, availability, freshness, and a useful primary action. Batch 23 adds platform-aware artwork loaded separately from request content, with a stable fallback when unavailable. Local implementation; deployed artwork/browser checks pending.
- [x] Search by game/achievement and filter by platform; show honest empty/error/loading states and pagination. Batch 21 uses server filters, 24-row pages, debounce, stale-response guards, and retry without discarding earlier pages.
- [x] **My activity** covering requests created, help offered, accepted partners, and completed sessions. Batch 21 adds My requests/My offers with offer status and a participant-history read policy. Local implementation; migration and production verification pending.
- [x] A clear accepted-session view with the next contact step and completion action, reusing existing contact functionality. Batch 23 adds a confirmed-team panel with session time, truthful owner/helper counts, platform contact copying, next steps, and completed-session presentation. Existing completion actions remain connected. Implemented locally.
- [x] Structured session time/timezone and participant needs. Batch 22 adds optional start time, UTC storage/local display with explicit offsets, and 1–7 additional players. Flexible availability remains supported. Implemented locally; migration/deployment pending.
- [x] Request freshness/reconfirmation so abandoned posts do not look active indefinitely. Batch 23 labels open requests needing confirmation after 30 days or an expired scheduled time. Owners explicitly reconfirm; server records the timestamp. Expired schedules require explicit agreement to flexible timing. No automatic expiry/removal or online-status claims. Migration/deployment pending.
- [x] Atomic acceptance, duplicate-offer protection, and account-aware refresh tied directly to this flow. Batch 22 adds owner-checked acceptance/decline/completion RPCs and serialized duplicate checks; concurrent capacity and duplicate-offer tests pass. Account refresh was implemented in batch 21. Deployment pending.
- [x] Private completed-session feedback and server-side outcome tracking. Batch 24 adds editable participant-only self-reports and first-acceptance/terminal timestamps, with unknown historical times left null. Implemented locally; migration/deployment pending.
- [x] Host rescheduling for active sessions, preserving accepted players and displaying when timing changed. Batch 25 adds future/flexible timing, save retries, and server revision checks against stale edits. No automatic notification or renewed-attendance claim. Implemented locally; migration/deployment pending.
- [ ] Validate browsing → request → offer → acceptance → contact → completion using test data, without sending real offers during review. Batch 24 passes the isolated database creation/offer/acceptance/completion/feedback journey and feedback widget tests. Automatic approval review blocked local REST-server setup without a specific reason; full REST/browser/contact validation remains open.

## Desktop feature visibility — batch 26

- [x] Surface existing next-action, daily momentum, and weekly recap cards on desktop, with direct destinations and persistent challenge/recap links. Implemented locally; responsive layout and navigation/retry/dismissal tests pass.
- [x] Balance completion-based suggestions with recent earned-achievement progress and explain the recommendation on desktop/mobile. Batch 27 is implemented locally; no new requests.
- [x] Let players request another game or reset suggestions on desktop/mobile. Batch 28 adds account-isolated session choices and browsing/reset when candidates are exhausted.
- [ ] Verify deployed browser behavior and measure whether discovery leads to challenge use, recap use, and subsequent progress.

## Revised order

1. Flex Room speed and readability.
2. Co-op hub redesign and completion of its user journey.
3. Surface existing next-action, challenge, and recap features consistently on desktop/mobile.

The broader infrastructure checklist remains available, but additional unrelated entitlement expansion should not displace these user-facing milestones. Required release security/payment checks still apply before deployment.

Local browser evidence is in `D:/.tmp/statusxp-flex-live-trace.json.gz`, `statusxp-coop-live-trace.json.gz`, `statusxp-flex-before.png`, `statusxp-coop-before.png`, and `statusxp-coop-mobile-before.png`. Traces/screenshots contain account-specific content and were left outside version-controlled project artifacts. Measurements are single desktop lab samples, not production percentiles or mobile-device benchmarks.
