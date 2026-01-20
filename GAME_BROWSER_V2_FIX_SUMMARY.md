# Game Browser V2 Schema Fix

## Problem
The game browser wasn't showing achievements because the code was using V1 schema fields, but the database is actually using V2 schema with composite keys.

## Root Cause
- Database uses V2 schema: `achievements(platform_id, platform_game_id, platform_achievement_id)`
- GameBrowserScreen was passing a single `gameId` to GameAchievementsScreen
- GameAchievementsScreen was querying using V1 fields `game_title_id` and `platform` text field
- V2 schema requires composite keys: `platform_id` + `platform_game_id`

## Changes Made

### 1. Database Function (`fix_browse_games_v2.sql`)
Updated `get_grouped_games_fast()` RPC function to return V2 composite keys:
- Added `platform_ids BIGINT[]` to return type
- Added `platform_game_ids TEXT[]` to return type  
- Added `primary_platform_id BIGINT` to return type
- Returns composite keys needed for V2 queries

### 2. Game Repository (`supabase_game_repository.dart`)
Updated `getAllGames()` to map V2 fields:
```dart
{
  'platform_id': finalPlatformId,        // V2 composite key part 1
  'platform_game_id': finalGameId,        // V2 composite key part 2
  'platform_ids': platformIds,            // All platforms in group
  'platform_game_ids': platformGameIds,   // All game IDs in group
}
```

### 3. Game Browser Screen (`game_browser_screen.dart`)
Updated all navigation to pass composite keys:
```dart
GameAchievementsScreen(
  platformId: platformId,           // Was: gameId
  platformGameId: platformGameId,   // New field
  gameName: name,
  platform: platformCode,
  coverUrl: coverUrl,
)
```

### 4. Game Achievements Screen (`game_achievements_screen.dart`)
Completely rewritten for V2 schema:

**Constructor:**
```dart
const GameAchievementsScreen({
  required this.platformId,      // V2: composite key part 1
  required this.platformGameId,  // V2: composite key part 2
  required this.gameName,
  required this.platform,
  this.coverUrl,
});
```

**Achievements Query:**
```dart
.from('achievements')
.select('''..., metadata''')  // Platform-specific data in JSONB
.eq('platform_id', widget.platformId!)
.eq('platform_game_id', widget.platformGameId!)
```

**User Achievements Query:**
```dart
.from('user_achievements')
.select('platform_achievement_id, earned_at')
.eq('user_id', userId)
.eq('platform_id', widget.platformId!)
.eq('platform_game_id', widget.platformGameId!)
```

**Platform-Specific Data:**
Now extracted from `metadata` JSONB column:
- `metadata['psn_trophy_type']` - PSN trophy type (bronze/silver/gold/platinum)
- `metadata['xbox_gamerscore']` - Xbox gamerscore value
- `metadata['xbox_is_secret']` - Xbox secret achievement flag
- `metadata['steam_hidden']` - Steam hidden achievement flag
- `metadata['is_dlc']` - DLC achievement flag
- `metadata['dlc_name']` - DLC name

## Steps to Deploy

1. **Run SQL Migration:**
   - Open Supabase SQL Editor
   - Copy contents of `fix_browse_games_v2.sql`
   - Execute the SQL to update the `get_grouped_games_fast()` function

2. **Test the Fix:**
   - Navigate to "Browse All Games"
   - Click on any game
   - Verify achievements list displays correctly
   - Check that earned achievements show properly
   - Test hidden/secret achievements toggle

3. **Verify V2 Schema:**
   The database should have these tables with composite keys:
   - `games(platform_id, platform_game_id)` ← Primary key
   - `achievements(platform_id, platform_game_id, platform_achievement_id)` ← Primary key
   - `user_achievements(user_id, platform_id, platform_game_id, platform_achievement_id)` ← Primary key
   - `user_progress(user_id, platform_id, platform_game_id)` ← Primary key

## Key Differences: V1 vs V2

| Aspect | V1 Schema (Old) | V2 Schema (Current) |
|--------|-----------------|---------------------|
| **Game ID** | Single `game_title_id` (bigint) | Composite `(platform_id, platform_game_id)` |
| **Platform** | Text field `platform` ('psn', 'xbox', 'steam') | Integer `platform_id` referencing `platforms` table |
| **Achievement ID** | `achievement_id` (bigint) | Composite `(platform_id, platform_game_id, platform_achievement_id)` |
| **Platform Data** | Separate columns (`psn_trophy_type`, `xbox_gamerscore`, etc.) | JSONB `metadata` column |
| **Duplicates** | Possible across platforms | Prevented by composite primary keys |

## Benefits of V2 Schema
- ✅ Prevents duplicate games across platforms
- ✅ Normalized platform handling via `platforms` table
- ✅ Composite keys ensure uniqueness
- ✅ Flexible platform-specific data via JSONB metadata
- ✅ Better support for multi-platform games

## Validation
After deploying, verify:
- [ ] Browse games loads without errors
- [ ] Clicking a game shows achievements
- [ ] User earned achievements display correctly
- [ ] Platform-specific icons (trophies/gamerscore) show correctly
- [ ] Hidden achievements toggle works
- [ ] DLC achievements are properly labeled
