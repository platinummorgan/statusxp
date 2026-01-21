# Platform ID Mapping Bug Fixes

## Issue Summary
Platform IDs were incorrectly mapped in database functions, causing PS3 games (platform_id=5) to potentially display with wrong platform names.

## Root Cause
The database function `get_grouped_games_fast` had incorrect platform_id mappings:

### ❌ INCORRECT Mappings (OLD)
```sql
WHEN 'ps3' THEN filter_platform_id := 2;   -- WRONG!
WHEN 'ps4' THEN filter_platform_id := 4;   -- WRONG!
WHEN 'steam' THEN filter_platform_id := 5;  -- WRONG!
```

### ✅ CORRECT Mappings (FIXED)
```sql
WHEN 'ps3' THEN filter_platform_id := 5;   -- CORRECT
WHEN 'ps4' THEN filter_platform_id := 2;   -- CORRECT
WHEN 'steam' THEN filter_platform_id := 4;  -- CORRECT
```

## Correct Platform IDs
(As defined in `sync-service/psn-sync.js` and database):

| Platform | Code | ID |
|----------|------|----|
| PS5 | PS5 | 1 |
| PS4 | PS4 | 2 |
| Steam | Steam | 4 |
| PS3 | PS3 | 5 |
| PSVITA | PSVITA | 9 |
| Xbox 360 | XBOX360 | 10 |
| Xbox One | XBOXONE | 11 |
| Xbox Series X | XBOXSERIESX | 12 |

## Files Fixed

### 1. `optimize_browse_games.sql` ✅
- Fixed platform filter mappings (lines 136-145)
- Status: **File updated, not yet deployed**

### 2. `fix_browse_games_achievements.sql` ✅
- Fixed platform filter mappings (lines 36-47)
- Status: **File updated, needs deployment**

### 3. `sql_archive/create_browse_games_function_v2.sql` ✅
- Fixed platform filter mappings
- Status: **Archived file, updated for completeness**

### 4. NEW: `supabase/migrations/1008_fix_platform_id_mappings.sql` ✅
- **Created new migration** to deploy the fix
- Updates `get_grouped_games_fast` function with correct mappings
- Ready to deploy to production

## Impact Analysis

### What This Bug Caused:
1. **PS3 filter**: Would query for platform_id=2 (PS4 games) instead of platform_id=5
2. **PS4 filter**: Would query for platform_id=4 (Steam games) instead of platform_id=2
3. **Steam filter**: Would query for platform_id=5 (PS3 games) instead of platform_id=4

### Result:
- Filtering by "PS3" would show PS4 games
- Filtering by "PS4" would show Steam games
- Filtering by "Steam" would show PS3 games

### What This Bug Did NOT Cause:
- ❌ Platform **names** display was NOT affected (arrays are correctly aligned)
- ❌ Game data integrity was NOT affected (games stored with correct platform_ids)
- ❌ Sync services were NOT affected (they use hardcoded correct IDs)

## Data Integrity Check

### Arrays ARE Correctly Aligned ✅
The SQL functions return data in this structure:
```javascript
{
  platform_ids: [1, 2, 5, 9],  // Ordered by platform_id
  platform_names: ['PlayStation 5', 'PlayStation 4', 'PlayStation 3', 'PlayStation Vita']  // Same order
}
```

Dart code accesses by array index:
```dart
final platformId = platformIds[index];  // Gets 5 at index 2
final platformName = platformNames[index];  // Gets 'PlayStation 3' at index 2
```

This works correctly because both arrays are ordered by `platform_id`.

## Additional Checks Performed

### ✅ Sync Services (Correct)
- `psn-sync.js`: Uses hardcoded IDs: `{ PS5: 1, PS4: 2, PS3: 5, PSVITA: 9 }` ✅
- `xbox-sync.js`: Uses hardcoded IDs: `{ 10: 'Xbox 360', 11: 'Xbox One', 12: 'Xbox Series X|S' }` ✅
- `steam-sync.js`: Uses platform_id=4 ✅

### ✅ Dart Code (Correct)
- `game_browser_screen.dart`: Uses array index access (aligned arrays) ✅
- `supabase_game_repository.dart`: Processes arrays correctly ✅

### ⚠️ Xbox Sync Edge Case
`xbox-sync.js` line 556-561 has a LOCAL `platformNames` object:
```javascript
const platformNames = { 10: 'Xbox 360', 11: 'Xbox One', 12: 'Xbox Series X|S' };
platformVersion = platformNames[existingOnAnyPlatform.platform_id];
```

**Potential Issue**: If a non-Xbox game somehow gets into Xbox sync results, `platformNames[5]` would be `undefined`.

**Risk**: Low - Xbox sync only processes Xbox games.

## Deployment Steps

1. ✅ **Review migration**: `supabase/migrations/1008_fix_platform_id_mappings.sql`
2. ⏳ **Deploy migration** to production database
3. ⏳ **Test platform filtering**:
   - Filter by "PS3" → Should show PS3 games (platform_id=5)
   - Filter by "PS4" → Should show PS4 games (platform_id=2)
   - Filter by "Steam" → Should show Steam games (platform_id=4)
4. ⏳ **Verify platform names** display correctly in UI

## Verification Queries

```sql
-- Check platform IDs in database
SELECT id, code, name FROM platforms ORDER BY id;

-- Check a PS3 game
SELECT g.name, g.platform_id, p.code, p.name
FROM games g
JOIN platforms p ON p.id = g.platform_id
WHERE g.platform_id = 5
LIMIT 5;

-- Test filter function
SELECT * FROM get_grouped_games_fast(NULL, 'ps3', 10, 0);
```

## Status

- ✅ Bug identified
- ✅ Root cause found
- ✅ Files fixed
- ✅ Migration created
- ⏳ Migration needs deployment
- ⏳ Testing needed after deployment
