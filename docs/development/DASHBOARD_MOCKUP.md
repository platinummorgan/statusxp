# Dashboard Mockup - Neon Purple StatusXP

## Color Palette

### Platform Colors
- **PSN**: `#00A8E1` (PlayStation Blue)
- **Xbox**: `#107C10` (Xbox Green)  
- **Steam**: `#1B2838` (Steam Dark Gray/Black)
- **StatusXP**: `#B026FF` (Neon Purple) ✨

## Layout Structure

```
┌─────────────────────────────────────────┐
│                                         │
│  [Avatar]  Dex-Morgan                  │
│            (PSN/Steam/Xbox selectable)  │
│                                         │
│         ┌──────────────────┐            │
│         │    StatusXP      │            │
│         │                  │            │
│         │     53,560       │            │
│         │                  │            │
│         └──────────────────┘            │
│          (NEON PURPLE)                  │
│                                         │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐ │
│  │Platinum │  │  Xbox   │  │ Steam   │ │
│  │   170   │  │  573    │  │  235    │ │
│  │ Games   │  │ Games   │  │ Games   │ │
│  │  366    │  │  25     │  │  35     │ │
│  │ AVG/G   │  │ AVG/G   │  │ AVG/G   │ │
│  │  25     │  │  ???    │  │  ???    │ │
│  └─────────┘  └─────────┘  └─────────┘ │
│   (PS BLUE)   (XBOX GREEN)  (STEAM BLK) │
│                                         │
│         Quick Actions                   │
│         ┌──────────────┐               │
│         │ View Games   │               │
│         └──────────────┘               │
│         ┌──────────────┐               │
│         │Status Poster │               │
│         └──────────────┘               │
│         ┌──────────────┐               │
│         │Leaderboards  │               │
│         └──────────────┘               │
└─────────────────────────────────────────┘
```

## Color Codes Reference

```dart
// StatusXP (Neon Purple - Cyberpunk accent)
Color statusXpColor = Color(0xFFB026FF);

// PSN (PlayStation Blue)
Color psnColor = Color(0xFF00A8E1);

// Xbox (Xbox Green)
Color xboxColor = Color(0xFF107C10);

// Steam (Dark/Black with subtle blue accent)
Color steamColor = Color(0xFF1B2838);
Color steamAccent = Color(0xFF66C0F4); // For borders/accents
```

## Visual Hierarchy

1. **StatusXP** - Largest circle, center top, neon purple glow
2. **Platform Circles** - Equal size, arranged horizontally below
3. **Username** - Top of screen with platform selection
4. **Quick Actions** - Bottom, secondary UI elements

## Neon Purple Rationale

- ✅ Classic cyberpunk color (referenced in existing `CyberpunkTheme.neonPurple`)
- ✅ Distinct from all platform colors
- ✅ Premium/special feel for unified cross-platform score
- ✅ High contrast on dark background
- ✅ Fits existing theme aesthetic
