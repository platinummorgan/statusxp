# DEPLOYMENT CHECKLIST - Game Browser V2 Fix

## Executive Summary
Fixed game browser achievements display issue by updating code to use V2 schema composite keys instead of V1 single game IDs.

## Database Change Required ✅

**CRITICAL: Run this SQL in Supabase SQL Editor FIRST:**

Location: `fix_browse_games_v2.sql`

This updates the `get_grouped_games_fast()` RPC function to return V2 composite keys (`platform_id`, `platform_game_id`) required by the updated Dart code.

## Code Changes Made ✅

### 1. Database Function
- **File**: `fix_browse_games_v2.sql`
- **Change**: Updated `get_grouped_games_fast()` to return `platform_id` and `platform_game_id`

### 2. Repository Layer
- **File**: `lib/data/repositories/supabase_game_repository.dart`
- **Change**: Maps V2 composite keys from RPC function response

### 3. UI - Game Browser
- **File**: `lib/ui/screens/game_browser_screen.dart`
- **Change**: Passes `platformId` and `platformGameId` to GameAchievementsScreen

### 4. UI - Game Achievements Screen
- **File**: `lib/ui/screens/game_achievements_screen.dart`
- **Changes**:
  - Constructor accepts `platformId` and `platformGameId` (nullable for compatibility)
  - Queries use V2 composite keys: `eq('platform_id', ...).eq('platform_game_id', ...)`
  - Platform-specific data extracted from `metadata` JSONB column

### 5. UI - Dashboard
- **File**: `lib/ui/screens/new_dashboard_screen.dart`
- **Change**: Updated both navigation calls to pass composite keys

### 6. UI - Unified Games List
- **File**: `lib/ui/screens/unified_games_list_screen.dart`  
- **Change**: Navigation passes composite keys

### 7. UI - Flex Room
- **File**: `lib/ui/screens/flex_room_screen.dart`
- **Change**: Navigation passes composite keys

### 8. Routing
- **File**: `lib/ui/navigation/app_router.dart`
- **Change**: Supports both V2 composite keys and V1 gameId from URL parameters

### 9. Domain Models
- **File**: `lib/domain/unified_game.dart`
- **Change**: Added `platformId` and `platformGameId` fields to `PlatformGameData`

- **File**: `lib/domain/flex_room_data.dart`
- **Change**: Added `platformId` and `platformGameId` fields to `FlexTile`

## Testing Steps

### 1. Deploy Database Change
```bash
# Copy SQL from fix_browse_games_v2.sql and run in Supabase SQL Editor
```

### 2. Restart Flutter App
```bash
# Stop the app and restart to load new code
flutter run
```

### 3. Test Browse Games
- [ ] Navigate to "Browse All Games"
- [ ] Search for a game
- [ ] Click on a game (single platform)
- [ ] Verify achievements list displays
- [ ] Check earned achievements show correctly

### 4. Test Multi-Platform Games
- [ ] Find a game available on multiple platforms
- [ ] Click the game
- [ ] Verify platform selection dialog appears
- [ ] Select a platform
- [ ] Verify achievements display for that platform

### 5. Test Dashboard
- [ ] Navigate to Dashboard
- [ ] Click on a game from your library
- [ ] Verify achievements display

### 6. Test Flex Room
- [ ] Navigate to Flex Room
- [ ] Click "View Trophy List" on any tile
- [ ] Verify achievements display

## Backwards Compatibility

The changes maintain backwards compatibility:
- Old `gameId` field still exists in domain models
- Navigation falls back to `gameId` if composite keys are null
- Router accepts both V2 query params and V1 path params
- GameAchievementsScreen validates composite keys and shows helpful error if missing

## Rollback Plan

If issues occur:
1. Revert the SQL function using git history
2. Revert Dart code changes
3. App will continue working with whatever schema exists

## Known Limitations

1. **RPC Functions Need Updates**: Some RPC functions like `get_user_grouped_games` still return V1 `game_title_id`. These will need gradual migration to V2.

2. **Platform Data in Metadata**: Platform-specific fields (trophy type, gamerscore, etc.) are now in the `metadata` JSONB column. Legacy data might have them in separate columns.

3. **Null Composite Keys**: Some code paths may have null `platformId` or `platformGameId` if data comes from older RPC functions. The code handles this gracefully by falling back to `gameId`.

## Future Work

- [ ] Update `get_user_grouped_games()` RPC to return V2 composite keys
- [ ] Update sync services to populate `metadata` JSONB column
- [ ] Migrate any remaining V1 references in codebase
- [ ] Add database migration to backfill platform_id values in existing data

## Success Criteria

✅ Browse games loads without errors
✅ Clicking a game shows achievements
✅ User earned achievements display correctly  
✅ Platform-specific icons (trophies/gamerscore) render correctly
✅ Hidden achievements toggle works
✅ DLC achievements properly labeled
✅ Dashboard game navigation works
✅ Flex room trophy list navigation works

## Documentation

See `GAME_BROWSER_V2_FIX_SUMMARY.md` for technical details about V1 vs V2 schema differences.
