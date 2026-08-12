# StatusXP Product Depth Roadmap

**Created:** August 12, 2026  
**Last reviewed:** August 12, 2026  
**Purpose:** Turn StatusXP from a collection of useful achievement features into a connected, cross-platform gaming identity ecosystem.

## Roadmap operating rules

This document is a living execution record and must be updated as roadmap work is performed. Repository state—not conversational memory—is the source of truth between sessions.

### Status legend

- `NOT STARTED` — No implementation work has begun.
- `IN DISCOVERY` — Requirements, data, UX, or technical constraints are being investigated.
- `READY` — Scope and acceptance criteria are sufficient to implement.
- `IN PROGRESS` — Implementation is actively underway.
- `BLOCKED` — Work cannot continue; the blocking condition and owner must be recorded.
- `VALIDATING` — Implementation exists and is undergoing tests, review, or production verification.
- `SHIPPED` — Acceptance criteria are met and the change is available in the intended environment.
- `DEFERRED` — Intentionally postponed with a recorded reason.

### Update requirements

Whenever roadmap work changes materially:

1. Update the relevant phase and work-item status.
2. Add the implementation date, concise outcome, and links to important files or migrations.
3. Record remaining work and known limitations; do not mark partial work `SHIPPED`.
4. Record decisions that affect product behavior, scoring, privacy, data contracts, or sequencing.
5. Record blockers with the exact condition needed to clear them.
6. Add or update validation evidence: automated tests, manual checks, analytics, or production verification.
7. Update **Last reviewed** at the top and add a changelog entry below.
8. Keep `_state/REALITY.md` synchronized when the production architecture or operational state changes.

### Phase tracker

| Phase | Status | Current outcome | Next checkpoint |
|---|---|---|---|
| Phase 0 — Inventory and measurement | `IN DISCOVERY` | Source-level inventory of all 37 routes completed in `docs/PHASE_0_ROUTE_FEATURE_INVENTORY.md`. | Validate routes at runtime and establish the baseline analytics list. |
| Phase 1 — Connected core | `VALIDATING` | Draft PRs #7–#8 implement the canonical library, game and achievement routes, repository-loaded entity data, analytics, contextual navigation, and composite-key comment reads/writes. | Apply the forward comment migration in a test environment and runtime-validate deep links, owner/non-owner states, navigation, and comment posting. |
| Phase 2 — Scoring trust | `IN DISCOVERY` | Hybrid current/earned-at policy and leaderboard requirements proposed. | Audit the live scoring implementation and approve the formal specification. |
| Phase 3 — Public identity | `NOT STARTED` | Target profile architecture defined. | Define privacy and RLS requirements. |
| Phase 4 — Data-rich entities | `NOT STARTED` | Target game and achievement hubs defined. | Complete Phase 1 entity routes first. |
| Phase 4B — Gaming Pulse | `IN DISCOVERY` | Product scope and rights-safe sourcing principles defined. | Approve source registry and ingestion policy. |
| Phase 5 — Discovery and intelligence | `NOT STARTED` | Target discovery and personalization outcomes defined. | Connect existing intelligence features to canonical entities. |
| Phase 6 — Community network | `NOT STARTED` | Target social architecture defined. | Complete public profiles and entity-linked activity first. |

### Decision log

| Date | Decision | Reason |
|---|---|---|
| 2026-08-12 | Build a connected cross-platform ecosystem rather than clone PocketPSN page for page. | StatusXP's defensible advantage is unified identity and personalized interpretation across platforms. |
| 2026-08-12 | Prioritize the connected entity core before adding more standalone feature screens. | Existing features are substantial but insufficiently connected. |
| 2026-08-12 | Place scoring trust immediately after the connected core. | StatusXP scoring is the namesake foundation for rankings, comparisons, recaps, and competitive identity. |
| 2026-08-12 | Prefer a hybrid score record: current value for ranking and earned-at value for history. | This preserves competitive fairness and historical context. |
| 2026-08-12 | Add Gaming Pulse as a cross-platform, library-aware content layer. | StatusXP needs daily utility even when users earn no achievements. |
| 2026-08-12 | Make the unified cross-platform library canonical at `/games`; retain `/unified-games` temporarily as a compatibility route. | One library eliminates overlapping navigation models while preserving a safe migration path. |
| 2026-08-12 | Use platform-scoped V2 composite identifiers and centrally mapped platform URL codes for game and achievement routes. | Platform IDs prevent collisions and repository-loaded metadata makes deep links durable. |
| 2026-08-12 | Add a dedicated privacy-safe `public_handle` later instead of exposing the existing username. | Existing usernames may be derived from email addresses and are not a safe public URL contract. |

### Progress changelog

#### 2026-08-12

- Audited the current production route surface and source-of-truth documentation.
- Identified connectivity and information depth—not raw feature count—as the primary product gap.
- Created this roadmap with canonical player, game, achievement, activity, social, intelligence, and content layers.
- Added Gaming Pulse for news, releases, and live events.
- Elevated scoring transparency and competitive depth to Phase 2.
- Added average StatusXP per achievement, categorized score deltas, formula versioning, and scoring safeguards.
- Established this document as the persistent roadmap execution record.
- Completed the initial 37-route source inventory, access classification, connectivity audit, unrouted-screen list, and canonical URL proposal in `docs/PHASE_0_ROUTE_FEATURE_INVENTORY.md`.
- Confirmed the Phase 1 blockers: no public profile route, game detail is only a redirect, no canonical achievement detail, and imperative navigation bypasses durable entity URLs.
- Selected the unified cross-platform library as the canonical `/games` experience and documented legacy-route compatibility.
- Approved platform-scoped V2 identifiers, readable platform URL codes, and a future privacy-safe `public_handle` contract.
- Defined the first implementable canonical game-hub slice and its acceptance criteria in `docs/PHASE_1_ENTITY_ROUTING_DECISIONS.md`.
- Implemented the first canonical game-hub slice in draft PR #7: `/games` now uses the unified library, `/unified-games` redirects for compatibility, and `/games/:platformCode/:platformGameId` loads canonical metadata and owner progress by composite key.
- Added tested handling for all approved platform URL codes, encoded identifiers, invalid links, loading failures, missing games, owner/non-owner progress, and library/catalog navigation.
- Validation evidence for PR #7: `flutter analyze` passed and all 6 focused `GameRef` tests passed.
- Implemented the stacked canonical achievement-detail slice in draft PR #8 with typed `AchievementRef` URLs, repository-loaded game/achievement data, rarity, StatusXP, earned state, composite-key comments, and contextual navigation.
- Replaced achievement-list comment links with canonical achievement destinations and added achievement-view analytics.
- Added a forward migration that makes the deprecated integer comment ID optional, preserving old clients while enabling canonical composite-key comment reads and writes without fabricated numeric IDs.
- Added the embedded, moderated comment composer to the canonical achievement page; applying and validating the migration remains a release prerequisite.
- Validation evidence for PR #8: `flutter analyze` passed and all 8 canonical reference tests passed.
- Release validation update: `flutter build web --release` completed successfully for the stacked implementation; the WebAssembly dry run reported only existing `dart:html`/`dart:js_util` compatibility warnings.
- GitHub validation update: PRs #7 and #8 are both mergeable with clean merge states; GitGuardian, Vercel deployment, and Vercel preview checks passed for both.
- Local Supabase migration lint remains pending because the Docker Desktop database engine is not running (`127.0.0.1:54322` unavailable). This is an environment blocker for local database validation, not a failed migration check.

## Executive decision

StatusXP should not attempt to out-PocketPSN PocketPSN by copying every PlayStation database page. Its defensible position is:

> **The best place to understand, improve, compare, and share your complete gaming identity across PlayStation, Xbox, and Steam.**

PocketPSN demonstrates the value of dense data, public discovery, and deeply connected entities. StatusXP already has strong differentiators—multi-platform sync, StatusXP scoring, recommendations, recaps, goals, rivals, seasons, a Flex Room, and sharing—but those features often behave like separate destinations.

The remedy is to build a connected product spine:

```text
Player <-> Game <-> Achievement <-> Activity
   |         |          |             |
 Profile   Insights   Community     Challenges
   |         |          |             |
 Follow    Compare     Guide/help    Share
```

Every major object should have a stable identity, a useful detail page, and links to related objects. New standalone features should be deprioritized until this spine is working.

## Product goals

1. Make StatusXP useful even before a user links an account.
2. Make every game, achievement, player, ranking, and feed item explorable.
3. Combine global context with personalized interpretation.
4. Make cross-platform identity—not raw database size—the defining advantage.
5. Increase useful information density without losing the StatusXP visual identity.
6. Use one canonical data and navigation model across web, iOS, and Android.

## Current-state assessment

### Existing strengths to preserve

- PlayStation, Xbox, and Steam synchronization
- Unified library and cross-platform dashboard
- Rarity-weighted StatusXP scoring
- Game and achievement catalog browsing
- Global and seasonal leaderboards plus Hall of Fame
- Flex Room, display case, and shareable status posters
- Weekly recaps, goals, pace coaching, achievement radar, and rival comparison
- Achievement comments and co-op help requests
- Premium subscription foundation

### Structural gaps to fix

- Most value is behind authentication; the public web experience is thin.
- Screens are feature-oriented rather than entity-oriented.
- Navigation frequently terminates instead of leading to related content.
- Public player profiles and player discovery are not first-class routes.
- Game detail is effectively an achievement-list route, not a complete game hub.
- Achievement detail is represented by comments rather than a canonical detail page.
- Global metadata and aggregate community context are inconsistent across platforms.
- Search, filtering, sorting, and URL-addressable state are not unified.
- Some screens contain stubs, dead taps, duplicate concepts, or generic imagery despite richer stored data.
- The README and product documentation no longer represent the production application accurately.

## Product architecture

### 1. Public player profile

Create a canonical route such as `/u/:handle` that works without authentication when the profile is public.

The page should include:

- Avatar, display name, linked platforms, privacy state, and last sync
- StatusXP score, overall rank, seasonal rank, and platform-specific ranks
- Total games, achievements, completions, completion rate, and rare unlocks
- Platform breakdown with PlayStation trophies, Xbox gamerscore, and Steam achievements
- Recent activity timeline
- Featured achievements and Flex Room preview
- Rarest unlocks, latest completions, favorite games, and current goals
- Comparison action, follow action, share action, and report/privacy controls
- Tabs for overview, games, achievements, activity, showcases, and statistics

The profile should be the primary shareable unit of StatusXP.

### 2. Canonical game hub

Replace the current game-detail redirect with a real route such as `/games/:platform/:gameId`.

The hub should contain:

- Cover, title, platforms, release metadata, developer/publisher, genre, and description
- Achievement/trophy breakdown and total available score
- User progress when signed in
- Community ownership, completion, average progress, and rarity distribution
- Estimated completion time when sufficient data exists
- Rarest and most-earned achievements
- DLC or title-update grouping
- Recent player activity
- Comments, tips, co-op requests, and guides
- Related games and cross-platform versions/stacks
- Tabs for overview, achievements, players, guides, and community

The same page must support three states: anonymous visitor, signed-in non-owner, and signed-in owner.

### 3. Canonical achievement detail

Create `/games/:platform/:gameId/achievements/:achievementId`.

Include:

- Real icon, name, description, tier/value, hidden state, and unlock requirements
- Global rarity and StatusXP value
- User earned state and exact earned timestamp
- Rarity classification and percentile context
- Unlock trend, recent earners, and related DLC group
- Tips/comments, guide content, co-op needs, and moderation controls
- Previous/next achievement navigation
- Shareable achievement card

Existing achievement comments should become one section of this page, not the page itself.

### 4. Global discovery

Upgrade the existing browser into a public discovery system:

- Unified search for players, games, and achievements
- Filter by platform, genre, release year, ownership, completion, rarity, and status
- Sort by newest, popular, most played, most completed, hardest, easiest, and trending
- Dedicated discovery collections such as “close to completion,” “abandoned,” “rare opportunities,” and “popular with similar players”
- Persist filter and sort state in URLs on web
- Provide useful empty, loading, error, and private-data states

### 5. Connected social layer

Use existing comments, co-op help, rivals, invites, and activity infrastructure as one coherent social system:

- Follow model rather than requiring mutual friendship for every interaction
- Following and discovery feeds
- Activity events that link to player, game, and achievement pages
- Likes/reactions with restrained notification behavior
- Comparison available from any public profile
- Co-op requests attached to the relevant game and achievement
- Community tips surfaced on game and achievement pages
- Blocks, reports, privacy controls, and rate limiting included from the start

### 6. Gaming Pulse: news, releases, and live events

Create a cross-platform daily destination rather than a generic article feed. The content layer should connect directly to the user's library and the canonical game system.

- Official news from PlayStation Blog, Xbox Wire, Steam news, publishers, and approved feeds
- Live and upcoming showcases, tournaments, award shows, maintenance windows, and community events
- Release calendar with platform, region, date, time, countdown, and availability
- Event pages with stream links, local-time conversion, reminders, related games, and post-event recaps
- News stories tagged to canonical games, franchises, publishers, and platforms
- Personalized sections: “For games you own,” “From your platforms,” “Upcoming from your backlog,” and “Trending with similar players”
- Follow games, franchises, publishers, or event categories
- Save, share, hide, and mark-as-read actions
- Separate editorial content from StatusXP product changelogs; the current `UpdatesScreen` remains an app-release history

Content must be sourced through permitted RSS/API/licensing arrangements. Store headlines, excerpts, attribution, canonical source URLs, tags, and normalized metadata; do not republish full copyrighted articles unless licensed. Prefer linking users to the original publisher while adding StatusXP-specific context.

### 7. Personal intelligence layer

Make StatusXP interpret the database rather than merely display it:

- “What should I play next?” with an explanation
- Closest completions and estimated effort
- Recently abandoned games worth returning to
- Rarity opportunities based on nearly completed achievement sets
- Goal progress and projected milestone dates
- Weekly and annual recaps that deep-link into the underlying entities
- Rival deltas: where the player gained or lost ground
- Cross-platform duplicates, stacks, and completion comparisons

## Delivery roadmap

The roadmap uses outcomes rather than calendar promises. A typical small team could treat each phase as roughly two to four weeks, but phases should ship only when their exit criteria are met.

### Phase 0 — Inventory, measurement, and cleanup

**Outcome:** The team knows which current capabilities are real, complete, discoverable, and used.

- Update the README and create a current feature inventory.
- Catalogue every route as public/private, free/premium, complete/stub, and mobile/web ready.
- Instrument page views, entity clicks, search usage, filter usage, and navigation exits.
- Find dead taps, TODO actions, duplicate screens, silent repository failures, and unused image fields.
- Establish canonical platform, game, achievement, and profile identifiers.
- Define privacy defaults and which aggregate statistics may be public.
- Record baseline activation, retention, pages per session, searches, shares, and sync success.

**Exit criteria**

- Every production route has an owner and status.
- Analytics can show the main user journeys and terminal screens.
- Canonical identifier and privacy contracts are documented.
- No new top-level feature is started without fitting the connected product architecture.

### Phase 1 — Connected core

**Outcome:** Players can move fluidly between the main entities.

- Build reusable entity references for player, game, achievement, and activity.
- Create canonical game and achievement routes.
- Replace query-string display metadata with repository-loaded canonical data.
- Make game cards, trophy rows, leaderboard entries, activity events, recap items, and Flex Room items open the correct entity.
- Use actual covers and achievement icons consistently, with resilient fallbacks.
- Add breadcrumbs or contextual back navigation on web and predictable back behavior on mobile.
- Add shareable deep links and 404/private/not-found handling.

**Exit criteria**

- A user can navigate player → game → achievement → community and back.
- No primary content card ends in a TODO or dead tap.
- Shared game and achievement URLs resolve independently of prior app state.
- Entity pages load from identifiers, not trusted query-string labels.

### Phase 2 — StatusXP scoring trust and competitive depth

**Outcome:** StatusXP becomes a transparent, credible cross-platform alternative to opaque rarity-point systems and raw achievement-count leaderboards.

This phase is higher priority than public profiles, Gaming Pulse, and new community features because StatusXP is the product's namesake and the foundation for ranks, comparisons, recommendations, and competitive identity.

- Publish the active StatusXP formula, inputs, exclusions, clamps, and formula version.
- Show the StatusXP value and calculation explanation on every achievement.
- Show earned StatusXP, available StatusXP, and percentage earned on every game.
- Add **average StatusXP per achievement** to profiles and leaderboard rows so collection quality is visible separately from volume.
- Add StatusXP gained/lost this week and explain recalculations caused by changing rarity or data corrections.
- Show total achievements beside total StatusXP to prevent a large score from being mistaken for difficulty alone.
- Add platform contribution breakdowns for PlayStation, Xbox, and Steam.
- Add overall, platform, seasonal, country, and friends/following leaderboard views where sample size supports them.
- Add minimum-owner/sample-confidence rules so tiny populations do not create extreme values.
- Audit DLC, title updates, regional stacks, duplicate achievement sets, unobtainables, hidden achievements, and cheated/invalid unlocks for score inflation.
- Version and backfill formula changes through auditable, idempotent jobs.

#### Scoring policy

Use a hybrid record:

- **Current StatusXP value:** recalculated from the current eligible rarity and used for competitive rankings.
- **Earned-at value:** preserved from the time of unlock for historical timelines, recaps, and personal records.
- **Score delta:** the difference caused by new unlocks, current-value recalculation, or administrative correction, with the cause labeled in the UI.

Until earned-at rarity can be captured reliably for every platform, mark historical values as unavailable rather than reconstructing them inaccurately. Existing unlocks may receive a clearly labeled baseline value at the formula migration date.

#### Required safeguards

- Define whether rarity uses platform-global data, StatusXP-tracked owners, or a confidence-adjusted combination.
- Require a minimum eligible-owner count before allowing maximum rarity value.
- Stabilize volatile rarity with a documented confidence or smoothing method.
- Treat DLC ownership separately where the denominator is reliable; otherwise label the limitation and cap inflation.
- Exclude or flag achievements that are unobtainable, malformed, duplicated, or statistically unreliable.
- Never change the formula silently; show the version, effective date, reason, and expected impact.

**Exit criteria**

- A user can explain why any achievement is worth its displayed StatusXP.
- Leaderboard rows show total score, achievement volume, average value, and recent delta.
- Every score change is attributable to unlocks, recalculation, or correction.
- Automated tests cover rarity boundaries, platform normalization, DLC inflation, small samples, duplicate stacks, and formula migrations.
- Leaderboard rebuilds are reproducible and do not depend on client calculations.

### Phase 3 — Public identity and comparison

**Outcome:** StatusXP profiles become valuable, searchable, and shareable destinations.

- Add public profile routes and profile visibility controls.
- Build the profile overview and tabs.
- Add player search by StatusXP handle and connected platform names where permitted.
- Link leaderboard rows, co-op users, commenters, and activity authors to profiles.
- Integrate rival comparison directly into public profiles.
- Generate social previews for public profile URLs on web.
- Add follow, block, report, and profile moderation flows.

**Exit criteria**

- A logged-out visitor can understand a public player’s gaming identity.
- Profile owners control visibility of platforms, activity, showcases, and detailed history.
- Public profile shares convert visitors into profile views and registrations measurably.

### Phase 4 — Data-rich game and achievement experience

**Outcome:** The catalog becomes a useful reference product, not just a user-library viewer.

- Add aggregate ownership, completion, rarity, and activity statistics.
- Add robust filters, sorting, pagination, and URL state.
- Model DLC/title updates and related platform versions explicitly.
- Add game-level player rankings and completion cohorts.
- Surface comments, co-op requests, and guides contextually.
- Introduce structured community guide sections: overview, missables, multiplayer, roadmap, and tips.
- Add data-quality reporting for incorrect names, images, grouping, and metadata.

**Exit criteria**

- Game pages are useful to visitors who have not played the game.
- Users can answer “how hard, how long, how rare, and what remains?” from one game hub.
- Achievement pages provide context beyond a title, icon, and rarity percentage.

### Phase 4B — Gaming Pulse

**Outcome:** StatusXP becomes useful on days when a user earns no achievements.

- Build the source registry, ingestion jobs, deduplication, tagging, attribution, and moderation controls.
- Launch a combined news, releases, and events feed with platform filters.
- Create canonical event pages, local-time rendering, calendar export, and reminders.
- Link content to game hubs and surface relevant stories on owned games.
- Add personalized “For You” ranking only after the chronological and platform-filtered feed is trustworthy.
- Instrument source clicks, follows, saves, reminders, and game-detail transitions.

**Exit criteria**

- Every item has a canonical source, attribution, ingestion timestamp, and rights-safe excerpt.
- Duplicate stories and stale/cancelled events can be corrected operationally.
- Users can move news/event → game → achievement/library context.
- The feed remains useful without requiring manual daily editorial work.

### Phase 5 — Discovery and intelligence

**Outcome:** StatusXP helps users decide what to do next.

- Launch unified search and discovery collections.
- Connect the existing radar, goals, pace, recap, and engagement features to canonical entities.
- Add transparent recommendation reasons and user feedback controls.
- Build “closest completion,” “backlog rescue,” and “rare opportunity” views.
- Add cross-platform version and duplicate detection.
- Use cached/database-computed recommendations first; reserve AI generation for explanations and guides where it adds value.

**Exit criteria**

- Recommendations lead directly to an actionable game or achievement.
- Users can dismiss or tune recommendations.
- Recommendation engagement and completion conversion can be measured.

### Phase 6 — Community network and retention

**Outcome:** User activity creates useful content and repeat visits without overwhelming the product.

- Launch following feeds and notifications.
- Add reactions, saved guides/tips, and contribution reputation.
- Improve co-op matching using platform, game, timezone, language, and availability.
- Add community moderation queues and contributor tools.
- Introduce challenges only when they connect to games, achievements, profiles, and feeds.
- Add annual recaps and durable milestone pages.

**Exit criteria**

- Feed events consistently link to meaningful destinations.
- Notification opt-outs and frequency controls are complete.
- Community reporting and moderation are operational before growth campaigns.

## Recommended first release slice

Do not begin with the entire roadmap. The first releasable vertical slice should be:

1. Canonical game route and game overview.
2. Canonical achievement route.
3. Actual imagery throughout both pages.
4. Navigation from My Games, game browser, dashboard activity, leaderboard/flex items, and weekly recap.
5. Achievement comments and co-op help embedded in context.
6. Deep-link and analytics coverage.

This slice reuses existing data and features while immediately making the application feel deeper.

## Data and backend work

Before adding new tables, audit the live schema and reuse current platform-composite keys.

Likely additions or formalizations include:

- Stable public profile handle and visibility fields
- Follow, block, report, and notification-preference records
- Game metadata enrichment and provenance
- Cross-platform game-family/version relationships
- Aggregate game and achievement statistics with refresh timestamps
- Activity-event schema with typed entity references
- Guide content, revisions, moderation state, and attribution
- Search indexes for profile handles, games, and achievements

Implementation rules:

- Never modify the baseline migration; add forward migrations.
- Maintain V1/V2 compatibility until deprecated fields are deliberately removed.
- Prefer materialized views or cached aggregates for expensive global statistics.
- Refresh aggregates after sync through queued/idempotent work, not in the critical user request.
- Treat public aggregate data separately from private user history in RLS policies.
- Add indexes and query budgets before launching public catalog endpoints.

## UX and design rules

- Information density means better hierarchy, not smaller text everywhere.
- Every overview card should answer a question or lead to detail.
- Use progressive disclosure: summary first, depth on tap.
- Prefer real game and achievement artwork over generic icons.
- Keep platform-specific scoring legible instead of forcing false equivalence.
- Use consistent terminology: game, achievement, trophy tier, completion, rarity, and StatusXP.
- Design empty, private, stale-sync, partial-platform, and error states deliberately.
- Preserve the neon identity but reduce decorative space where it competes with useful data.
- Ensure web layouts take advantage of width instead of stretching mobile cards.

## Metrics

### North-star metric

**Weekly users who complete at least two meaningful connected actions**, such as viewing a game detail and an achievement detail, comparing a profile, saving a tip, acting on a recommendation, or sharing a profile.

### Supporting metrics

- Successful first platform link and first sync rate
- Time from signup to first useful insight
- Public profile views and profile-share conversion
- Entity detail views per active user
- Search-to-detail click-through rate
- Average connected pages per session
- Recommendation click and subsequent achievement/completion rate
- Weekly recap open and deep-link rate
- Comment, tip, co-op offer, and accepted-help rates
- D7 and D30 retention by linked-platform count
- Sync success, freshness, query latency, and error rates
- Average StatusXP per achievement distribution and percentile
- Weekly score delta split by new unlocks, rarity recalculation, and corrections
- Percentage of score-bearing achievements meeting the sample-confidence threshold
- Formula-version migration variance and leaderboard rank movement

Avoid optimizing raw screen count, feed impressions, notification volume, or AI calls as success metrics.

## Prioritization framework

Score proposed work against these questions:

1. Does it strengthen player, game, achievement, or activity as a canonical entity?
2. Does it connect two or more existing features?
3. Is it useful with the data already available?
4. Does it improve the public or shareable product surface?
5. Can its user outcome be measured?
6. Does it preserve platform API limits and privacy expectations?

Work scoring poorly on these questions stays in the backlog even if it is visually exciting.

## Explicit non-goals for the next phases

- Copying PocketPSN’s PlayStation-only feature set page for page
- Building forums before contextual comments, tips, and co-op flows are cohesive
- Adding more isolated premium screens
- Launching guilds/clans before profiles and following work reliably
- Treating AI-generated text as a substitute for accurate structured data
- Chasing the largest possible catalog before current entity pages and links are sound
- Redesigning the entire visual system before fixing hierarchy and connectivity

## Immediate engineering backlog

1. Produce the route/feature inventory from Phase 0.
2. Specify canonical entity IDs and URL formats.
3. Write and approve the StatusXP scoring specification, hybrid value policy, confidence rules, and formula-version contract.
4. Add average StatusXP per achievement and categorized weekly score deltas to the leaderboard data contract.
5. Replace `/game/:gameId` redirection with a game overview shell.
6. Add a canonical achievement route and move comments into it.
7. Audit all `onTap` handlers and TODO/stub actions on primary surfaces.
8. Standardize reusable cover, achievement-icon, platform-badge, rarity, progress, and StatusXP explanation components.
9. Add entity-click and navigation-exit analytics.
10. Draft public-profile privacy and RLS requirements.
11. Define aggregate-stat queries and performance budgets.
12. Define the Gaming Pulse source, attribution, deduplication, and correction policy.
13. Update README and architecture documentation after the first connected-core release.

## Definition of success

StatusXP has rectified the depth gap when a visitor can discover a player or game, understand it without prior context, navigate into increasingly specific detail, compare that information to themselves or another player, take an action, and share the result—without encountering a dead end or needing to return to the dashboard.
