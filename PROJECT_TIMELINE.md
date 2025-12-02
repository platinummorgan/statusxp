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
**Status:** 🟢 In Progress - 56% Complete

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

#### Milestone 2.2: Navigation Structure ✅
- [x] Set up app navigation framework (GoRouter)
- [x] Define route structure
  - Dashboard (/) - home/root
  - Games List (/games)
  - Status Poster (/poster)
- [x] Implement navigation with context.go()
- [x] Add error/404 handling
- [x] Created all three core screens
- [x] Web-compatible declarative routing
- [x] Updated tests for navigation

#### Milestone 2.3: Dashboard Screen ⬜
- [ ] Design dashboard layout
- [ ] Implement header with username
- [ ] Create stats summary cards
  - Total Platinums (prominent)
  - Total Games Tracked
  - Total Trophies
  - Hardest Platinum
  - Rarest Trophy (name + rarity %)
- [ ] Add visual hierarchy and spacing
- [ ] Implement responsive layout
- [ ] Add navigation to Games List
- [ ] Add navigation to Status Poster

### Milestone Block 3: Core Features & Polish

#### Milestone 3.1: Games List Screen ⬜
- [ ] Design game list item layout
- [ ] Display game cover (placeholder or asset)
- [ ] Show game name and platform
- [ ] Display trophy progress
  - Progress bar
  - Earned/Total count
  - Percentage
- [ ] Add platinum indicator
- [ ] Show rarest trophy percentage
- [ ] Implement scrollable list
- [ ] Add sorting options (optional for v0.1)
- [ ] Add search/filter (optional for v0.1)

#### Milestone 3.2: Status Poster Screen ⬜
- [ ] Design poster layout concept
  - User identity section (username, avatar placeholder)
  - Key stats visualization
  - Highlight accomplishments
  - Visual style: gaming stat card aesthetic
- [ ] Implement poster UI
- [ ] Add trophy showcase section
- [ ] Add top games display
- [ ] Add rarity/difficulty highlights
- [ ] Implement responsive scaling
- [ ] Apply neon accent styling
- [ ] Add visual polish (gradients, shadows, effects)

#### Milestone 3.3: Polish & Testing ⬜
- [ ] End-to-end navigation testing
- [ ] UI/UX review and refinement
- [ ] Performance optimization
- [ ] Accessibility check
- [ ] Test on multiple screen sizes
- [ ] Bug fixes and edge cases
- [ ] Code cleanup and documentation
- [ ] Prepare v0.1 demo build

---

## 📋 PHASE 0.2: Enhanced Prototype (FUTURE)

**Goal:** Add local data editing and export functionality  
**Status:** 🔵 Planned

### Features
- [ ] Manual game entry/editing
- [ ] Trophy data editing
- [ ] Delete/archive games
- [ ] Export poster as image
- [ ] Share functionality
- [ ] Basic settings screen

---

## 📋 PHASE 0.3: Cloud Foundation (FUTURE)

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
