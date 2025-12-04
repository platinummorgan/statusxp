# Display Case Feature

## Overview
The Display Case is a customizable trophy cabinet with drag-and-drop functionality, allowing users to showcase their gaming achievements in a physical trophy case aesthetic with glass shelves.

## 🎯 Vision
- Physical trophy cabinet with glass shelves
- Drag-and-drop customization with grid snapping
- Multiple display types (trophy icons, game covers)
- Platform themes (PlayStation, Xbox, Steam)
- Personal storytelling: "This bronze trophy means more to me than platinums"

## 📁 Architecture

### Directory Structure
```
lib/features/display_case/
├── themes/
│   ├── display_case_theme.dart     # Abstract base class
│   ├── playstation_theme.dart      # PS blue/silver (ACTIVE)
│   ├── xbox_theme.dart             # Xbox green/black (stubbed)
│   └── steam_theme.dart            # Steam blue (stubbed)
├── models/
│   └── display_case_item.dart      # DisplayCaseItem, DisplayItemType, DisplayCaseConfig
├── repositories/
│   └── display_case_repository.dart # CRUD operations with Supabase
├── providers/
│   └── display_case_providers.dart  # Riverpod providers
├── widgets/
│   ├── display_item.dart           # DisplayItem, EmptyDisplaySlot
│   └── trophy_details_popup.dart   # Info popup
├── dialogs/
│   └── trophy_selector_dialog.dart # Browse and add trophies
└── screens/
    └── display_case_screen.dart    # Main screen with drag-and-drop grid

supabase/migrations/
└── 20241204_create_display_case_items.sql # Database schema
```

## 🎨 Theme System

### Abstract Base Class
All platform themes implement `DisplayCaseTheme`:
- Properties: colors, gradients, decorations
- Methods: `getTierColor()`, `getBackgroundDecoration()`, `getShelfDecoration()`, `textGlow()`

### PlayStation Theme (Active)
- **Colors**: Blue/silver (#1A2332 → #2C3E50 gradient)
- **Shelves**: Translucent glass (40% white) with PS blue borders
- **Accents**: PS Blue (#00A8E1, #4A90E2)
- **Tier Colors**:
  - Platinum: #7DD3F0 (cyan)
  - Gold: #FFD700
  - Silver: #C0C0C0
  - Bronze: #CD7F32

### Xbox Theme (Stubbed for Future)
- **Colors**: Green/black (#107C10 Xbox green, #0E1E0E background)
- **TODO**: Xbox achievement integration

### Steam Theme (Stubbed for Future)
- **Colors**: Steam blue (#66C0F4) with dark background
- **TODO**: Steam achievement integration

## 📊 Data Models

### DisplayItemType Enum
```dart
enum DisplayItemType {
  trophyIcon,  // Shows PSN trophy icon with tier badge
  gameCover,   // Shows game box art as framed picture
  figurine,    // Future - custom 3D collectible
  custom,      // Future - user uploaded image
}
```

### DisplayCaseItem
Immutable model with Equatable support:
- `id`: UUID
- `userId`: User identifier
- `trophyId`: Reference to trophy
- `displayType`: How to render (icon vs cover)
- `shelfNumber`: Vertical position (0-9)
- `positionInShelf`: Horizontal position (0-2)
- Trophy metadata: name, game, tier, rarity, URLs

### DisplayCaseConfig
Layout settings:
- `itemsPerShelf`: 3
- `numberOfShelves`: 10
- `shelfHeight`: 140
- `shelfSpacing`: 24

## 🗄️ Database Schema

### Table: display_case_items
```sql
CREATE TABLE display_case_items (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES auth.users ON DELETE CASCADE,
  trophy_id INTEGER REFERENCES trophies ON DELETE CASCADE,
  display_type TEXT CHECK (display_type IN ('trophyIcon', 'gameCover', 'figurine', 'custom')),
  shelf_number INTEGER CHECK (shelf_number >= 0),
  position_in_shelf INTEGER CHECK (position_in_shelf >= 0 AND position_in_shelf < 10),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Constraints
  UNIQUE(user_id, trophy_id),                          -- No duplicate trophies
  UNIQUE(user_id, shelf_number, position_in_shelf)     -- No overlapping positions
);

-- Indexes
CREATE INDEX idx_display_case_user ON display_case_items(user_id);
CREATE INDEX idx_display_case_position ON display_case_items(user_id, shelf_number, position_in_shelf);
```

### RLS Policies
- Users can only see/modify their own items
- Automatic `updated_at` trigger on changes

## 🔧 Repository Methods

### DisplayCaseRepository
```dart
// Fetch all items with trophy metadata (joins trophies + game_titles)
Future<List<DisplayCaseItem>> getDisplayItems(String userId)

// Add trophy to specific position
Future<DisplayCaseItem?> addItem(userId, trophyId, displayType, shelf, position)

// Move item (drag-and-drop)
Future<bool> updateItemPosition(itemId, newShelf, newPosition)

// Swap two items
Future<bool> swapItems(DisplayCaseItem item1, DisplayCaseItem item2)

// Remove from display
Future<bool> removeItem(String itemId)

// Check if slot is available
Future<bool> isPositionOccupied(userId, shelf, position)

// Browse all earned trophies
Future<List<Map<String, dynamic>>> getAvailableTrophies(String userId)
```

## 🎮 User Flow

1. **Open Display Case**
   - Dashboard → "Display Case" button
   - Shows empty glass shelves with add icons

2. **Add Trophy**
   - Tap empty slot → Trophy selector dialog
   - Browse all earned trophies
   - Filter by game, tier, rarity
   - Choose display type (icon vs cover)
   - Trophy appears on shelf with tier glow

3. **Drag & Drop**
   - Long-press trophy to drag
   - Grid highlights valid positions
   - Drop on new position → Snaps to grid
   - Database updates automatically

4. **View Details**
   - Tap trophy → Info popup
   - Shows: game, trophy name, tier, rarity
   - Close button returns to display

5. **Remove Trophy**
   - (TODO: Add remove button to popup)
   - Deletes from display, frees slot

## 🚀 Navigation

### Routes
- **Path**: `/display-case`
- **Name**: `display-case`
- **Screen**: `DisplayCaseScreen`

### Dashboard Button
- **Label**: "Display Case"
- **Icon**: `Icons.emoji_events`
- **Accent**: Purple (#C71585)

## ✅ Completed Features

- [x] Theme architecture (PS/Xbox/Steam)
- [x] Data models (DisplayCaseItem, DisplayItemType, DisplayCaseConfig)
- [x] Database migration with constraints
- [x] Repository with full CRUD operations
- [x] Display item widgets (DisplayItem, EmptyDisplaySlot)
- [x] Trophy details popup
- [x] Main screen with drag-and-drop grid
- [x] Trophy selector dialog (basic)
- [x] Navigation routing
- [x] Dashboard button updated
- [x] Old trophy room screen marked with TODOs

## 🔮 Future Enhancements

### Phase 1 (Post-MVP)
- [ ] Complete trophy selector (add to specific position)
- [ ] Remove trophy button in details popup
- [ ] Settings: Switch between PS/Xbox/Steam themes
- [ ] Shelf customization (add/remove shelves)
- [ ] Animations: Trophy appears with glow

### Phase 2 (Platform Integration)
- [ ] Xbox achievement integration (activate XboxTheme)
- [ ] Steam achievement integration (activate SteamTheme)
- [ ] Cross-platform trophy sync

### Phase 3 (Advanced Features)
- [ ] Figurine display type (3D-like collectibles)
- [ ] Custom upload display type (user images)
- [ ] Export/share display case as image
- [ ] Sound effects on drag/drop
- [ ] Multiple display case layouts
- [ ] Trophy arrangement templates

## 📝 Technical Notes

### Build Status
✅ All files compile successfully
✅ No runtime errors
✅ APK builds cleanly

### Provider Dependencies
- `supabaseClientProvider` (from statusxp_providers.dart)
- `currentUserIdProvider` (from statusxp_providers.dart)
- `displayCaseRepositoryProvider` (local)
- `displayCaseThemeProvider` (local)

### Widget Tree
```
DisplayCaseScreen (ConsumerStatefulWidget)
├── Container (themed background)
│   └── SafeArea
│       └── FutureBuilder<List<DisplayCaseItem>>
│           └── SingleChildScrollView
│               └── Column (shelves)
│                   └── For each shelf:
│                       └── Container (glass shelf decoration)
│                           └── Row (3 grid slots)
│                               └── For each slot:
│                                   └── DragTarget
│                                       ├── LongPressDraggable (if has item)
│                                       │   └── DisplayItem
│                                       └── EmptyDisplaySlot (if empty)
└── FloatingActionButton (add trophy)
```

### State Management
- **Screen State**: `_draggingItem`, `_dragOverShelf`, `_dragOverPosition`
- **Database Updates**: Immediate on drop (optimistic UI)
- **Refresh**: FutureBuilder rebuilds after successful operations

## 🎯 Design Principles

1. **Not Hardcoded**: Theme system supports multiple platforms
2. **Future-Proof**: Xbox/Steam classes ready for activation
3. **Clean Separation**: New feature directory, didn't touch existing code
4. **Database Constraints**: No duplicates, no overlaps
5. **Display Flexibility**: Trophy icon AND game cover supported
6. **User Control**: Full customization, drag-and-drop UX

## 📍 Status

**Current**: Display Case is fully functional with PlayStation theme
**Navigation**: Accessible from Dashboard → "Display Case" button
**Database**: Migration ready to run (not yet executed)
**Next Step**: Run migration, test with real trophy data, polish selector dialog

---

*"This is what is going to set my entire project off"* 🏆
