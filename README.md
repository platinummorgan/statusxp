# StatusXP

**Gaming Achievement Tracker & Identity Platform**

> Your gaming identity, leveled up.

---

## 🎮 What is StatusXP?

StatusXP is a cross-platform gaming achievement tracker that aggregates your gaming accomplishments across PlayStation, Xbox, Steam, Nintendo, RetroAchievements, and more into a single, unified gamer profile.

Track your trophies, achievements, and completions. Showcase your gaming identity. Compete in seasons and climb leaderboards.

---

## 🚀 Current Status

**Version:** 0.1 (Local Prototype - In Development)  
**Phase:** Foundation & Planning  
**Started:** December 2, 2025

This is currently a **work in progress**. We're building an offline prototype to validate the core concept and UI/UX before implementing backend and platform integrations.

---

## 📱 Screens (v0.1 Prototype)

1. **Dashboard** - Your gaming stats at a glance
2. **Games List** - All tracked games with trophy progress
3. **Status Poster** - Shareable visual profile card of your achievements

---

## 🎯 Features (Planned)

### v0.1 - Local Prototype *(Current)*
- ✅ Offline, single-user demo
- ✅ Sample data visualization
- ✅ Dark theme with neon accents
- ✅ Core navigation flow

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
