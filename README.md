# StatusXP

**Gaming Achievement Tracker & Identity Platform**

> Your gaming identity, leveled up.

---

## 🎮 What is StatusXP?

StatusXP is a cross-platform gaming achievement tracker that aggregates your gaming accomplishments across PlayStation, Xbox, Steam, Nintendo, RetroAchievements, and more into a single, unified gamer profile.

Track your trophies, achievements, and completions. Showcase your gaming identity. Compete in seasons and climb leaderboards.

---

## 🚀 Current Status

**Version:** 0.2.2 (Local Persistence + Editing)  
**Phase:** Phase 0.2 - Enhanced Prototype - In Progress  
**Started:** December 2, 2025  
**Latest Update:** December 2, 2025

Phase 0.2.1 (Local JSON persistence with Riverpod) and 0.2.2 (Game editing) are **complete**! ✅

All data now persists to local JSON files with Riverpod state management. Users can edit existing games with automatic stats recalculation. All 7 widget tests passing.

**Ready for:** Demo, showcase, user feedback, Phase 0.2.3 (add/delete games)

---

## 📱 Screens (v0.2)

1. **Dashboard** - Your gaming stats at a glance (live data from JSON)
2. **Games List** - All tracked games with trophy progress (tappable cards)
3. **Game Detail** - Edit game properties (name, platform, trophies, rarity)
4. **Status Poster** - Shareable visual profile card of your achievements

---

## 🎯 Features

### v0.1 - Local Prototype ✅ **Complete**
- ✅ Offline, single-user demo
- ✅ Sample data visualization (12 games)
- ✅ Dark theme with neon accents
- ✅ Core navigation flow (push-based routing)
- ✅ Dashboard with micro-animations
- ✅ Games list with formatting helpers
- ✅ Status Poster with screenshot & share functionality
- ✅ Haptic feedback on all primary actions

### v0.2.1 - Local Persistence ✅ **Complete**
- ✅ Riverpod state management (flutter_riverpod ^2.5.1)
- ✅ Repository pattern (GameRepository, UserStatsRepository)
- ✅ JSON file persistence in app documents directory
- ✅ First-run seeding from sample data
- ✅ Async data loading with FutureProvider
- ✅ All screens converted to ConsumerWidget

### v0.2.2 - Game Editing ✅ **Complete**
- ✅ Edit existing tracked games (name, platform, trophies, rarity)
- ✅ Tappable game cards navigate to detail screen
- ✅ Full-featured edit form with validation
- ✅ Automatic user stats recalculation after edits
- ✅ Local persistence of changes
- ✅ Success/error feedback with SnackBars
- ✅ Provider refresh after mutations

- ✅ Demo Mode label (sample data only)
- ✅ About StatusXP dialog with version info
- ✅ Version 0.1.0 prototype build
- ✅ Widget tests (6 test cases, all passing)
- ✅ Deployed to physical device (Android 16)

### Future Phases
- 📊 Cloud sync & user accounts
- 🎮 Platform integrations (PSN, Xbox, Steam, etc.)
- 🏆 Seasonal progression & leaderboards
- 👥 Rivals and social features
- 📸 Shareable achievement cards
- ✅ Anti-cheat validation

---

## 🛠️ Tech Stack

**Mobile/Web Framework:** Flutter (Dart)  
**Backend:** TBD (planned Supabase or Firebase in Phase 0.3)  
**Database:** TBD (planned PostgreSQL/Firestore in Phase 0.3)

**Architecture Pattern:**  
MVVM-inspired structure using Providers (or Riverpod) for state management.  
Clear separation of domain, data, and UI layers.

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

**Platform Note:**  
All UI and architecture must be structured to support future Flutter Web deployment. Even though v0.1 targets mobile UI first, the codebase must remain platform-agnostic and responsive.

---

## 📂 Project Structure

```
statusxp/
├── PROJECT_TIMELINE.md    # Detailed development timeline
├── PROGRESS_LOG.md        # Session-by-session progress tracking
├── README.md              # This file
└── (source code to come)
```

---

## 🎨 Design Direction

**Theme:** Dark mode with neon-style accents  
**Vibe:** Modern gaming UI, stat cards, Spotify Wrapped aesthetic  
**Colors:** Dark backgrounds + electric neon highlights (blue/purple/green)

---

## 👥 Development Team

**Architecture & Guidance:** ChatGPT 5.1  
**Code Implementation:** Claude 4.5 (Sonnet)  
**Workflow:** Guidance → Code → Review → Iterate

---

## 📖 Documentation

- [Project Timeline](PROJECT_TIMELINE.md) - Full implementation roadmap
- [Progress Log](PROGRESS_LOG.md) - Development journal and session notes

---

## 🚦 Getting Started

*Instructions will be added once project is initialized*

---

## 📄 License

*To be determined*

---

## 💬 Contact

*Contact information to be added*

---

**StatusXP** - *Level up your gaming identity* 🎮✨
# Force rebuild 2026-01-21 15:24
