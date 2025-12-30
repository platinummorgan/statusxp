# StatusXP - Project Timeline & Implementation Plan

**Project Start Date:** December 2, 2025  
**Current Phase:** v0.1 Local Prototype (Offline MVP)  
**Tech Stack:** Flutter (Dart) - Mobile First, Web Compatible  
**Architecture:** MVVM with Provider/Riverpod State Management  
**Development Workflow:** ChatGPT 5.1 (Architecture/Guidance) → Claude 4.5 (Code Implementation)

**Platform Note:** All UI and architecture must be structured to support future Flutter Web deployment. Even though v0.1 targets mobile UI first, the codebase must remain platform-agnostic and responsive.

---

## 🎯 Project Vision

StatusXP is a cross-platform gaming achievement tracker and identity app that aggregates gaming accomplishments (trophies, achievements, completions) across multiple platforms into a unified gamer profile with stats, highlights, and shareable visual cards.

**Long-term Goal:** Competitive ecosystem with seasons, leaderboards, rank progression, and community verification.

**Supported Platforms (Future):** PlayStation, Xbox, Steam, Nintendo, RetroAchievements, Manual Entry

---

## 📋 PHASE 0.1: Local Prototype - Foundation (CURRENT)

**Goal:** Build offline, single-user prototype to validate core identity and UI feel  
**Duration Estimate:** 2-3 weeks  
**Status:** 🟢 Complete - 100% ✅

### Milestone Block 1: Foundation & Data Layer ✅ COMPLETE

#### Milestone 1.1: Project Setup & Architecture ✅
- [x] Initialize Flutter project
- [x] Set up development environment (Flutter SDK, IDE)
- [x] Create project structure
- [x] Configure development environment
- [x] Set up version control (git)
- [x] Define folder structure:
  - `/lib/domain` - Models, entities, core logic
  - `/lib/data` - Sample data, repositories
  - `/lib/state` - Providers/Riverpod state
  - `/lib/ui/screens` - Screen widgets
  - `/lib/ui/widgets` - Reusable components
  - `/lib/theme` - Theme, colors, text styles
- [x] Configure linting (analysis_options.yaml)
- [x] Set up coding standards (const, immutable, Equatable)

#### Milestone 1.2: Data Models ✅
- [x] Create `Game` model class
  - Fields: id, name, platform, totalTrophies, earnedTrophies, hasPlatinum, rarityPercent, cover
  - Immutable, equatable, JSON serialization support
  - Added completionPercent computed property
- [x] Create `UserStats` model class
  - Fields: username, totalPlatinums, totalGamesTracked, totalTrophies, hardestPlatGame, rarestTrophyName, rarestTrophyRarity
  - Immutable, equatable, JSON serialization support
- [x] Add comprehensive documentation to models
- [x] Installed equatable dependency

#### Milestone 1.3: Sample Data Generation ✅
- [x] Create sample data in /lib/data/sample_data.dart
- [x] Generate 12 realistic game entries
  - Mix of platforms (PS5, PS4, Xbox)
  - Varied completion percentages (65%-100%)
  - Realistic trophy counts (28-119 trophies)
- [x] Generate UserStats instance with calculated totals
- [x] Add placeholder cover references
- [x] All data validated and consistent

### Milestone Block 2: UI/UX Implementation

#### Milestone 2.1: Theme & Design System ✅
- [x] Define dark theme color palette
  - Base dark backgrounds (0xFF0A0A0F, 0xFF12121A, 0xFF1B1B26)
  - Neon accent colors (blue, purple, green, yellow)
  - Text hierarchy colors (white, white70, white38)
- [x] Create custom theme configuration (statusXPTheme)
- [x] Define typography scale (11 text styles from display to label)
- [x] Create reusable widget components
  - StatCard with neon glow effect
  - SectionHeader for content organization
  - Configured card, button, and input themes
- [x] Created theme demo screen
- [x] All theme files pass analyzer with zero errors

#### Milestone 2.2: Navigation Structure + UI Polish ✅
- [x] Set up app navigation framework (GoRouter)
- [x] Define route structure
  - Dashboard (/) - home/root
  - Games List (/games)
  - Status Poster (/poster)
- [x] Implement push-based navigation (context.push/pop)
- [x] Add error/404 handling
- [x] Created all three core screens with polish
- [x] Web-compatible declarative routing
- [x] Updated tests for navigation
- [x] Fixed username layout on Status Poster
- [x] Tightened spacing and improved visual hierarchy
- [x] Unified card radius (16px)
- [x] Upgraded Quick Actions buttons with neon accents
- [x] Fixed overflow issues on poster screen

#### Milestone 2.3: Navigation Improvements ✅
- [x] Implemented push-based navigation (context.push instead of context.go)
- [x] Added back buttons to Games List screen
- [x] Added back button to Status Poster screen
- [x] All navigation flows tested and working

#### Milestone 2.4: Share Functionality ✅
- [x] Added screenshot package dependency (^3.0.0)
- [x] Added share_plus package (^10.0.2)
- [x] Added path_provider package (^2.1.4)
- [x] Implemented screenshot capture for Status Poster card
- [x] Screenshot captures poster card only (excludes AppBar)
- [x] Integrated native share sheet on mobile
- [x] Saves screenshot to temp PNG file before sharing
- [x] Share functionality tested on physical device

#### Milestone 2.3: Dashboard Screen ✅
- [x] Design dashboard layout
- [x] Implement header with username
- [x] Create stats summary cards
  - Total Platinums (prominent)
  - Games Tracked, Total Trophies
  - Hardest Platinum, Rarest Trophy
- [x] Add micro-animation (400ms enter animation for stats section)
- [x] AnimatedOpacity + AnimatedSlide for smooth entrance
- [x] Haptic feedback on Quick Actions buttons
- [x] Add visual hierarchy and spacing
- [x] Implement responsive layout
- [x] Add navigation to Games List
- [x] Add navigation to Status Poster

### Milestone Block 3: Core Features & Polish

#### Milestone 3.1: Games List Screen ✅
- [x] Design game list item layout
- [x] Display game cover (placeholder or asset)
- [x] Show game name and platform
- [x] Display trophy progress
  - Progress bar
  - Earned/Total count
  - Percentage with 1 decimal formatting
- [x] Add platinum indicator
- [x] Show rarest trophy percentage
- [x] Implement scrollable list
- [x] Added formatting helpers (_formatCompletionPercent, _formatRarity)
- [x] Ensured consistent typography across game cards
- [x] Haptic feedback on back button

#### Milestone 3.2: Status Poster Screen ✅
- [x] Design poster layout concept
  - User identity section (username, avatar placeholder)
  - Key stats visualization
  - Highlight accomplishments
  - Visual style: gaming stat card aesthetic
- [x] Implement poster UI
- [x] Add trophy showcase section
- [x] Add top games display
- [x] Add rarity/difficulty highlights
- [x] Implement responsive scaling
- [x] Apply neon accent styling
- [x] Add visual polish (gradients, shadows, effects)
- [x] Haptic feedback on share button and back button
- [x] Screenshot functionality captures poster card only (excludes AppBar)

#### Milestone 3.3: Polish & Testing ✅
- [x] End-to-end navigation testing (4 widget tests, all passing)
- [x] UI/UX review and refinement
  - Dashboard micro-animation (400ms enter animation)
  - Formatting helpers for consistent data display
  - Haptic feedback on all 6 primary interaction points
- [x] Performance optimization
  - Animation uses postFrameCallback for smooth rendering
  - Screenshot efficiently captures only poster card
- [x] Test on multiple screen sizes (1080x2400 test size, physical device tested)
- [x] Bug fixes and edge cases
  - Fixed screenshot package compatibility (upgraded to ^3.0.0)
  - Fixed test isolation issues (consolidated tests)
- [x] Code cleanup and documentation
  - flutter analyze: 0 errors, 17 info-level const suggestions
  - All imports organized
  - Comprehensive comments and documentation
- [x] Prepare v0.1 demo build
  - Deployed to Samsung SM S926U (Android 16)
  - All features tested and working on physical device

#### Milestone 0.1: Finalization ✅
- [x] Add "Demo Mode · Sample data only" badge to Dashboard
- [x] Implement About StatusXP dialog accessible from AppBar overflow menu
- [x] About dialog shows app version (0.1.0 Prototype), tagline, and prototype disclaimer
- [x] Haptic feedback on About menu interaction
- [x] Version bumped to 0.1.0+1 in pubspec.yaml
- [x] Widget test added for About dialog functionality
- [x] All 6 tests passing (4 navigation + 1 content + 1 about dialog)
- [x] Final documentation updates

**Phase 0.1 Scope Fully Delivered** 🎉

---

## 📋 PHASE 0.2: Enhanced Prototype - Local Persistence & Editing

**Goal:** Add local data persistence and editing functionality  
**Status:** 🟢 In Progress

### Milestone 0.2.1: Local JSON Persistence with Riverpod ✅ COMPLETE
- [x] Add flutter_riverpod dependency (^2.5.1)
- [x] Create repository layer
  - [x] GameRepository interface + LocalFileGameRepository
  - [x] UserStatsRepository interface + LocalFileUserStatsRepository
  - [x] JSON file persistence in app documents directory
  - [x] First-run seeding from sample_data.dart
- [x] Implement Riverpod providers
  - [x] gameRepositoryProvider, userStatsRepositoryProvider
  - [x] gamesProvider (FutureProvider<List<Game>>)
  - [x] userStatsProvider (FutureProvider<UserStats>)
- [x] Convert all screens to Riverpod
  - [x] Dashboard: ConsumerWidget with ref.watch()
  - [x] Games List: ConsumerWidget with async .when()
  - [x] Status Poster: ConsumerWidget with async .when()
- [x] Update tests with ProviderScope
  - [x] Override providers with sample data in tests
  - [x] All 6 tests passing

### Milestone 0.2.2: Game Editing (Update Only) ✅ COMPLETE
- [x] Domain: UserStatsCalculator helper
  - [x] Pure function to recompute UserStats from games
  - [x] Calculates totals, platinum count, hardest trophy
- [x] Data: GameEditService
  - [x] Handle game updates with stats recalculation
  - [x] Ensure data consistency across repositories
- [x] State: Editing providers
  - [x] userStatsCalculatorProvider
  - [x] gameEditServiceProvider
  - [x] StatusXPRefresh extension for invalidation
- [x] UI: Make game cards tappable
  - [x] GameListTile onTap callback
  - [x] Haptic feedback on tap
  - [x] Navigation to GameDetailScreen
- [x] UI: GameDetailScreen
  - [x] Full edit form with validation
  - [x] Fields: name, platform, platinum, trophies, rarity
  - [x] Save with auto-refresh
  - [x] Success/error feedback
- [x] Tests: game_edit_flow_test.dart
  - [x] Test navigation to detail screen
  - [x] Validate form fields
  - [x] Test editing capability
  - [x] All 7 tests passing
- [x] flutter analyze: 0 errors

### Milestone 0.2.3: Add/Delete Games (PLANNED)
- [ ] Add "Add Game" floating action button on Games List
- [ ] Create AddGameScreen with empty form
- [ ] Implement GameEditService.addGame()
- [ ] Implement GameEditService.deleteGame()
- [ ] Add delete confirmation dialog
- [ ] Update tests for add/delete flows

---

## 📋 PHASE 0.3: Analytics & Insights (FUTURE)


**Goal:** Backend infrastructure and user accounts  
**Status:** 🔵 Planned

### Features
- [ ] Backend architecture selection
- [ ] User authentication system
- [ ] Cloud data storage
- [ ] Data sync (local ↔ cloud)
- [ ] User profile management
- [ ] Privacy controls

---

## 📋 PHASE 1.0: Platform API Integration (FUTURE)

**Goal:** Connect real gaming platform APIs  
**Status:** 🔵 Planned  
**Prerequisites:** Must complete Phase 0.1 (prototype), 0.2 (local editing), and 0.3 (cloud foundation) first

⚠️ **Important:** Platform integrations require backend infrastructure. Do not attempt until cloud foundation is complete.

### PlayStation Integration
- [ ] PSN API research and authentication
- [ ] Trophy data import pipeline
- [ ] Game metadata fetch
- [ ] Sync automation
- [ ] Rate limiting and error handling

### Xbox Integration
- [ ] Xbox Live API integration
- [ ] Achievement import
- [ ] Gamerscore tracking

### Steam Integration
- [ ] Steam API integration
- [ ] Achievement import
- [ ] Game library sync

### Additional Platforms
- [ ] Nintendo integration research
- [ ] RetroAchievements API
- [ ] Manual entry improvements

---

## 📋 PHASE 2.0: Competitive Features (FUTURE)

**Goal:** Build competitive ecosystem  
**Status:** 🔵 Planned

### Features
- [ ] Seasonal system design
- [ ] Leaderboard implementation
- [ ] Rank progression system
- [ ] Rival system
- [ ] Point calculation algorithms
- [ ] Anti-cheat validation rules
- [ ] Community verification

---

## 📋 PHASE 3.0: Social & Community (FUTURE)

**Goal:** Build social features and community  
**Status:** 🔵 Planned

### Features
- [ ] User profiles (public/private)
- [ ] Following/followers
- [ ] Activity feeds
- [ ] Comparisons with friends
- [ ] Challenges
- [ ] Community features

---

## 🎨 Design Direction

**Brand Identity:** Dark theme with neon-style accents  
**Inspiration:** Gaming stat cards, Spotify Wrapped, modern gaming UIs  
**Key Elements:**
- Dark backgrounds (near-black, dark grays)
- Neon accent colors (electric blue, purple, green options)
- Clean typography
- Card-based layouts
- Trophy/achievement iconography
- Progress visualizations

---

## 🛠️ Tech Stack

**Mobile/Web Framework:** Flutter (Dart)  
**State Management:** Provider or Riverpod  
**Architecture:** MVVM-inspired with clean separation of concerns

**Backend (Phase 0.3+):**
- Supabase or Firebase (TBD)

**Database (Phase 0.3+):**
- PostgreSQL or Firestore (TBD)

**Folder Structure:**
```
/lib
  /domain        # Models, entities, core logic
  /data          # Sample data, repositories (future: services)
  /state         # Providers/Riverpod state
  /ui
    /screens
    /widgets
  /theme         # Theme, color scheme, text styles
```

**Coding Standards:**
- Use Dart `const` constructors where possible
- Prefer immutable data classes
- Use Equatable for value equality
- Use responsive layouts (no hardcoded pixel sizes)
- Keep all UI in `/ui`, all logic in `/domain`
- Keep sample data separate in `/data`
- Use theme-based styling, no inline colors

---

## 📊 Success Metrics for v0.1

- ✅ Three screens fully navigable
- ✅ All sample data displays correctly
- ✅ Dark theme with neon accents applied consistently
- ✅ Smooth transitions and professional UI feel
- ✅ Demonstrates core concept clearly
- ✅ "Wow factor" in Status Poster screen
- ✅ Ready to demo to stakeholders/testers

---

## 📝 Notes & Decisions Log

*This section will track key architectural decisions, pivot points, and important notes throughout development.*

---

## 🔄 Development Workflow

1. **Guidance Phase:** ChatGPT 5.1 provides architecture, feature breakdown, and task planning
2. **Implementation Phase:** Claude 4.5 generates code following specifications
3. **Review Phase:** Test, validate, iterate
4. **Progress Phase:** Update tracking documents, move to next milestone

---

**Last Updated:** December 2, 2025  
**Current Sprint:** Foundation & Setup
